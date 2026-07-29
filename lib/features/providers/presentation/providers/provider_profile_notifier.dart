import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_codec.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/provider_connection_result.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ProviderIdFactory = String Function();
typedef ProviderCancellationControllerFactory =
    CancellationController Function();

enum ProviderProfileAction {
  idle,
  loading,
  saving,
  deleting,
  testing,
  discovering,
}

final class ProviderProfileState {
  ProviderProfileState({
    Iterable<ProviderProfile> profiles = const <ProviderProfile>[],
    this.activeProfileId,
    this.selectedProfileId,
    Map<String, Iterable<ModelDescriptor>> discoveredModels =
        const <String, Iterable<ModelDescriptor>>{},
    this.schemaVersion = ProviderProfilesCodec.currentSchemaVersion,
    this.legacyMigrationState = LegacyMigrationState.notStarted,
    this.action = ProviderProfileAction.loading,
    this.failure,
    this.failureMessage,
    this.connectionMessage,
    this.creating = false,
  }) : profiles = List.unmodifiable(List<ProviderProfile>.from(profiles)),
       discoveredModels = Map.unmodifiable(<String, List<ModelDescriptor>>{
         for (final entry in discoveredModels.entries)
           entry.key: List<ModelDescriptor>.unmodifiable(entry.value),
       });

  final List<ProviderProfile> profiles;
  final String? activeProfileId;
  final String? selectedProfileId;
  final Map<String, List<ModelDescriptor>> discoveredModels;
  final int schemaVersion;
  final LegacyMigrationState legacyMigrationState;
  final ProviderProfileAction action;
  final AppFailure? failure;
  final String? failureMessage;
  final String? connectionMessage;
  final bool creating;

  ProviderProfile? get activeProfile => profileFor(activeProfileId);
  ProviderProfile? get selectedProfile => profileFor(selectedProfileId);
  bool get isLoading => action == ProviderProfileAction.loading;
  bool get hasUsableActiveProfile => _isUsable(activeProfile);
  String? get selectedModelId => activeProfile?.selectedModelId;
  String? get selectedModel => selectedModelId;
  List<String> get manualModels =>
      activeProfile?.manualModelIds ?? const <String>[];
  List<ModelDescriptor> get discoveredModelsForActive => activeProfile == null
      ? const <ModelDescriptor>[]
      : discoveredModels[activeProfile!.id] ?? const <ModelDescriptor>[];
  bool get insecureLocalHttp {
    final profile = selectedProfile ?? activeProfile;
    if (profile == null) return false;
    final validation = ProviderUrlPolicy.validate(profile.endpoint);
    return validation is Success<ProviderUrlValidation> &&
        validation.value.warnings.contains(
          ProviderUrlWarning.insecureLocalHttp,
        );
  }

  ProviderProfile? profileFor(String? id) {
    if (id == null) return null;
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  ProviderProfileState copyWith({
    Iterable<ProviderProfile>? profiles,
    String? activeProfileId,
    String? selectedProfileId,
    Map<String, Iterable<ModelDescriptor>>? discoveredModels,
    int? schemaVersion,
    LegacyMigrationState? legacyMigrationState,
    ProviderProfileAction? action,
    AppFailure? failure,
    String? failureMessage,
    String? connectionMessage,
    bool? creating,
    bool clearActive = false,
    bool clearSelected = false,
    bool clearFailure = false,
    bool clearConnection = false,
  }) => ProviderProfileState(
    profiles: profiles ?? this.profiles,
    activeProfileId: clearActive
        ? null
        : activeProfileId ?? this.activeProfileId,
    selectedProfileId: clearSelected
        ? null
        : selectedProfileId ?? this.selectedProfileId,
    discoveredModels: discoveredModels ?? this.discoveredModels,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    legacyMigrationState: legacyMigrationState ?? this.legacyMigrationState,
    action: action ?? this.action,
    failure: clearFailure ? null : failure ?? this.failure,
    failureMessage: clearFailure ? null : failureMessage ?? this.failureMessage,
    connectionMessage: clearConnection
        ? null
        : connectionMessage ?? this.connectionMessage,
    creating: creating ?? this.creating,
  );

  static bool _isUsable(ProviderProfile? profile) =>
      profile != null && profile.enabled && !profile.deletionPending;
}

/// Transient form values. Secret values never enter [ProviderProfile] or state.
final class ProviderProfileDraft {
  const ProviderProfileDraft({
    this.id,
    required this.providerId,
    required this.displayName,
    required this.endpoint,
    required this.enabled,
    required this.timeout,
    this.headers = const <String, String>{},
    this.secretHeaderNames = const <String>[],
    this.secretHeaderValues = const <String, String>{},
    this.apiKey,
    this.removeApiKey = false,
    this.removeSecretHeaders = const <String>[],
    this.manualModelIds = const <String>[],
    this.selectedModelId,
  });

  final String? id;
  final String providerId;
  final String displayName;
  final String endpoint;
  final bool enabled;
  final Duration timeout;
  final Map<String, String> headers;
  final List<String> secretHeaderNames;
  final Map<String, String> secretHeaderValues;
  final String? apiKey;
  final bool removeApiKey;
  final List<String> removeSecretHeaders;
  final List<String> manualModelIds;
  final String? selectedModelId;
}

final class ProviderProfileNotifier
    extends StateNotifier<ProviderProfileState> {
  factory ProviderProfileNotifier({
    required ProviderProfileRepository repository,
    required CredentialStore credentials,
    required ProviderRegistry registry,
    required ProviderCancellationControllerFactory
    cancellationControllerFactory,
    required ProviderIdFactory idFactory,
    ProviderProfileState? initialState,
  }) => ProviderProfileNotifier._(
    repository,
    credentials,
    registry,
    cancellationControllerFactory,
    idFactory,
    initialState,
  );

  ProviderProfileNotifier._(
    this._repository,
    this._credentials,
    this._registry,
    this._cancellationControllerFactory,
    this._idFactory,
    ProviderProfileState? initialState,
  ) : super(initialState ?? ProviderProfileState());

  final ProviderProfileRepository _repository;
  final CredentialStore _credentials;
  final ProviderRegistry _registry;
  final ProviderCancellationControllerFactory _cancellationControllerFactory;
  final ProviderIdFactory _idFactory;
  CancellationController? _discoveryCancellation;
  int _requestEpoch = 0;

  Future<void> load() async {
    state = state.copyWith(
      action: ProviderProfileAction.loading,
      clearFailure: true,
      clearConnection: true,
    );
    final loaded = await _repository.load();
    switch (loaded) {
      case Failure<ProviderProfilesDocument>(:final error):
        _failure(error, action: ProviderProfileAction.idle);
        return;
      case Success<ProviderProfilesDocument>(:final value):
        final selected =
            value.profiles.any(
              (profile) => profile.id == state.selectedProfileId,
            )
            ? state.selectedProfileId
            : value.activeProfileId;
        state = ProviderProfileState(
          profiles: value.profiles,
          activeProfileId: value.activeProfileId,
          selectedProfileId: selected,
          discoveredModels: state.discoveredModels,
          schemaVersion: value.schemaVersion,
          legacyMigrationState: value.legacyMigrationState,
          action: ProviderProfileAction.idle,
          creating: state.creating,
        );
    }
  }

  void beginCreate() => state = state.copyWith(
    creating: true,
    clearSelected: true,
    clearFailure: true,
    clearConnection: true,
  );

  void selectProfile(String profileId) {
    if (state.profileFor(profileId) == null) return;
    _requestEpoch++;
    _discoveryCancellation?.cancel();
    state = state.copyWith(
      selectedProfileId: profileId,
      creating: false,
      clearFailure: true,
      clearConnection: true,
    );
  }

  Future<void> activateProfile(String profileId) async {
    final profile = state.profileFor(profileId);
    if (!_canRun(profile)) return;
    _requestEpoch++;
    await _saveDocument(
      state.profiles,
      activeProfileId: profileId,
      selectedProfileId: profileId,
    );
  }

  Future<void> saveProfile(ProviderProfileDraft draft) async {
    final validation = _validateDraft(draft);
    if (validation != null) {
      _validation(validation);
      return;
    }
    final existing = draft.id == null ? null : state.profileFor(draft.id!);
    final id = existing?.id ?? _idFactory();
    if (existing == null && state.profileFor(id) != null) {
      _validation('A provider profile with this identifier already exists.');
      return;
    }
    if (state.profiles.any(
      (profile) =>
          profile.id != id &&
          profile.displayName.toLowerCase() ==
              draft.displayName.trim().toLowerCase(),
    )) {
      _validation('A provider profile with this display name already exists.');
      return;
    }
    final endpointResult = ProviderUrlPolicy.parseAndValidate(draft.endpoint);
    late final Uri endpoint;
    switch (endpointResult) {
      case Failure<ProviderUrlValidation>(:final error):
        _failure(error, action: ProviderProfileAction.idle);
        return;
      case Success<ProviderUrlValidation>(:final value):
        endpoint = value.uri;
    }
    final secretNames = _normalizedHeaderNames(draft.secretHeaderNames);
    final removedSecretNames = _removedSecretNames(
      existing,
      secretNames,
      draft.removeSecretHeaders,
    );
    final secretValues = _normalizedSecretValues(
      draft.secretHeaderValues,
      secretNames,
    );
    final secretValidation = _validateNewSecretValues(
      existing,
      id,
      secretNames,
      secretValues,
    );
    if (secretValidation != null) {
      _validation(secretValidation);
      return;
    }
    final manualModels = _normalizedModels(draft.manualModelIds);
    final selectedModel = draft.selectedModelId?.trim();
    if (selectedModel != null &&
        selectedModel.isNotEmpty &&
        !manualModels.contains(selectedModel) &&
        !(state.discoveredModels[id]?.any(
              (model) => model.id == selectedModel,
            ) ??
            false)) {
      _validation('Select a model that is available for this profile.');
      return;
    }
    final apiReference = ProviderCredentialReference.apiKey(id);
    final apiValue = draft.apiKey?.trim();
    final hadApiReference = existing?.credentialId == apiReference;
    final credentialId = draft.removeApiKey
        ? null
        : (hadApiReference || (apiValue?.isNotEmpty ?? false)
              ? apiReference
              : null);
    final profile = ProviderProfile(
      id: id,
      providerId: draft.providerId,
      displayName: draft.displayName.trim(),
      endpoint: endpoint,
      credentialId: credentialId,
      headers: Map<String, String>.from(draft.headers),
      secretHeaderNames: secretNames,
      secretHeaderCredentialIds: <String, String>{
        for (final name in secretNames)
          name: ProviderCredentialReference.secretHeader(id, name),
      },
      manualModelIds: manualModels,
      selectedModelId: selectedModel?.isEmpty == true ? null : selectedModel,
      enabled: draft.enabled,
      timeout: draft.timeout,
    );
    _requestEpoch++;
    _discoveryCancellation?.cancel();
    state = state.copyWith(
      action: ProviderProfileAction.saving,
      clearFailure: true,
      clearConnection: true,
    );
    final newlyWritten = <String>[];
    if (apiValue != null && apiValue.isNotEmpty && !hadApiReference) {
      final result = await _credentials.write(apiReference, apiValue);
      if (result case Failure<void>(:final error)) {
        _failure(error, action: ProviderProfileAction.idle);
        return;
      }
      newlyWritten.add(apiReference);
    }
    for (final entry in secretValues.entries) {
      final reference = ProviderCredentialReference.secretHeader(id, entry.key);
      final existingReference = existing?.secretHeaderCredentialIds[entry.key];
      if (existingReference == reference) continue;
      final result = await _credentials.write(reference, entry.value);
      if (result case Failure<void>(:final error)) {
        await _deleteNewReferences(newlyWritten);
        _failure(error, action: ProviderProfileAction.idle);
        return;
      }
      newlyWritten.add(reference);
    }
    final profiles = <ProviderProfile>[
      ...state.profiles.where((item) => item.id != id),
      profile,
    ];
    final active = state.activeProfileId == id && !profile.enabled
        ? null
        : state.activeProfileId ?? (profile.enabled ? id : null);
    final saved = await _repository.save(_document(profiles, active));
    if (saved case Failure<void>(:final error)) {
      await _deleteNewReferences(newlyWritten);
      _failure(error, action: ProviderProfileAction.idle);
      return;
    }
    _commitSaved(profiles, activeProfileId: active, selectedProfileId: id);
    final cleanupFailure = await _finishCredentialMutations(
      existing: existing,
      profile: profile,
      apiValue: apiValue,
      removeApiKey: draft.removeApiKey,
      secretValues: secretValues,
      removedSecretNames: removedSecretNames,
    );
    if (cleanupFailure != null) {
      _failure(cleanupFailure, action: ProviderProfileAction.idle);
    }
  }

  Future<void> deleteProfile(String profileId) async {
    final profile = state.profileFor(profileId);
    if (profile == null) return;
    _requestEpoch++;
    _discoveryCancellation?.cancel();
    state = state.copyWith(
      action: ProviderProfileAction.deleting,
      clearFailure: true,
      profiles: state.profiles.map(
        (item) =>
            item.id == profile.id ? item.copyWith(deletionPending: true) : item,
      ),
    );
    final result = await _repository.deleteProfile(profile.id, _credentials);
    if (result case Failure<void>(:final error)) {
      await load();
      _failure(error, action: ProviderProfileAction.idle);
      return;
    }
    await load();
  }

  Future<void> deleteSelectedProfile() async {
    final id = state.selectedProfileId;
    if (id != null) await deleteProfile(id);
  }

  Future<void> testConnection(String profileId) async {
    final profile = state.profileFor(profileId);
    if (!_canRun(profile)) return;
    final target = profile!;
    final adapter = _registry.adapterFor(target.providerId);
    if (adapter == null) {
      _validation('This provider is unavailable.');
      return;
    }
    final request = ++_requestEpoch;
    final cancellation = _cancellationControllerFactory();
    state = state.copyWith(
      action: ProviderProfileAction.testing,
      clearFailure: true,
      clearConnection: true,
    );
    final result = await adapter.testConnection(target, cancellation.token);
    if (!_isCurrentRequest(request, target.id)) return;
    switch (result) {
      case Failure<ProviderConnectionResult>(:final error):
        _failure(error, action: ProviderProfileAction.idle);
      case Success<ProviderConnectionResult>(:final value):
        state = state.copyWith(
          action: ProviderProfileAction.idle,
          connectionMessage: value.isConnected
              ? 'Connection verified.'
              : 'Connection could not be verified.',
        );
    }
  }

  Future<void> discoverModels(String profileId) async {
    final profile = state.profileFor(profileId);
    if (!_canRun(profile)) return;
    final target = profile!;
    final adapter = _registry.adapterFor(target.providerId);
    if (adapter == null || !_supportsDiscovery(target)) {
      _discoveryUnavailable();
      return;
    }
    _discoveryCancellation?.cancel();
    final cancellation = _cancellationControllerFactory();
    _discoveryCancellation = cancellation;
    final request = ++_requestEpoch;
    state = state.copyWith(
      action: ProviderProfileAction.discovering,
      clearFailure: true,
    );
    final result = await adapter.discoverModels(target, cancellation.token);
    if (!identical(cancellation, _discoveryCancellation) ||
        cancellation.token.isCancelled ||
        !_isCurrentRequest(request, target.id)) {
      return;
    }
    switch (result) {
      case Failure<List<ModelDescriptor>>():
        _discoveryUnavailable();
      case Success<List<ModelDescriptor>>(:final value):
        state = state.copyWith(
          action: ProviderProfileAction.idle,
          discoveredModels: <String, Iterable<ModelDescriptor>>{
            ...state.discoveredModels,
            target.id: _uniqueDescriptors(value),
          },
          clearFailure: true,
        );
    }
  }

  Future<void> addManualModel(String profileId, String value) async {
    final profile = state.profileFor(profileId);
    final model = value.trim();
    if (profile == null || model.isEmpty) {
      _validation('Enter a model ID.');
      return;
    }
    if (!_canRun(profile)) return;
    final updated = profile.copyWith(
      manualModelIds: _normalizedModels(<String>[
        ...profile.manualModelIds,
        model,
      ]),
      selectedModelId: model,
    );
    await _replaceProfile(updated, selectedProfileId: profileId);
  }

  Future<void> selectModel(String profileId, String modelId) async {
    final profile = state.profileFor(profileId);
    if (!_canRun(profile)) return;
    final available = <String>{
      ...profile!.manualModelIds,
      ...?state.discoveredModels[profileId]?.map((model) => model.id),
    };
    if (!available.contains(modelId)) {
      _validation('Select a model that is available for this profile.');
      return;
    }
    await _replaceProfile(profile.copyWith(selectedModelId: modelId));
  }

  Future<void> _replaceProfile(
    ProviderProfile profile, {
    String? selectedProfileId,
  }) => _saveDocument(
    state.profiles
        .map((item) => item.id == profile.id ? profile : item)
        .toList(growable: false),
    activeProfileId: state.activeProfileId,
    selectedProfileId: selectedProfileId ?? state.selectedProfileId,
  );

  Future<void> _saveDocument(
    Iterable<ProviderProfile> profiles, {
    required String? activeProfileId,
    required String? selectedProfileId,
  }) async {
    _requestEpoch++;
    _discoveryCancellation?.cancel();
    state = state.copyWith(
      action: ProviderProfileAction.saving,
      clearFailure: true,
    );
    final document = _document(profiles, activeProfileId);
    final result = await _repository.save(document);
    if (result case Failure<void>(:final error)) {
      _failure(error, action: ProviderProfileAction.idle);
      return;
    }
    _commitSaved(
      document.profiles,
      activeProfileId: document.activeProfileId,
      selectedProfileId: selectedProfileId,
    );
  }

  ProviderProfilesDocument _document(
    Iterable<ProviderProfile> profiles,
    String? activeProfileId,
  ) => ProviderProfilesDocument(
    schemaVersion: state.schemaVersion,
    profiles: profiles,
    activeProfileId: activeProfileId,
    legacyMigrationState: state.legacyMigrationState,
  );

  void _commitSaved(
    Iterable<ProviderProfile> profiles, {
    required String? activeProfileId,
    required String? selectedProfileId,
  }) {
    final document = _document(profiles, activeProfileId);
    state = state.copyWith(
      profiles: document.profiles,
      activeProfileId: document.activeProfileId,
      selectedProfileId: selectedProfileId,
      action: ProviderProfileAction.idle,
      creating: false,
      clearFailure: true,
    );
  }

  Future<AppFailure?> _finishCredentialMutations({
    required ProviderProfile? existing,
    required ProviderProfile profile,
    required String? apiValue,
    required bool removeApiKey,
    required Map<String, String> secretValues,
    required Iterable<String> removedSecretNames,
  }) async {
    final id = profile.id;
    final apiReference = ProviderCredentialReference.apiKey(id);
    if (apiValue != null &&
        apiValue.isNotEmpty &&
        existing?.credentialId == apiReference) {
      final result = await _credentials.write(apiReference, apiValue);
      if (result case Failure<void>(:final error)) return error;
    }
    for (final entry in secretValues.entries) {
      final reference = ProviderCredentialReference.secretHeader(id, entry.key);
      if (existing?.secretHeaderCredentialIds[entry.key] != reference) continue;
      final result = await _credentials.write(reference, entry.value);
      if (result case Failure<void>(:final error)) return error;
    }
    if (removeApiKey && existing?.credentialId == apiReference) {
      final result = await _credentials.delete(apiReference);
      if (result case Failure<void>(:final error)) return error;
    }
    for (final name in removedSecretNames) {
      final reference = existing?.secretHeaderCredentialIds[name];
      if (reference == null) continue;
      final result = await _credentials.delete(reference);
      if (result case Failure<void>(:final error)) return error;
    }
    return null;
  }

  Future<void> _deleteNewReferences(Iterable<String> references) async {
    for (final reference in references) {
      await _credentials.delete(reference);
    }
  }

  bool _isCurrentRequest(int request, String profileId) =>
      request == _requestEpoch && state.profileFor(profileId) != null;

  bool _canRun(ProviderProfile? profile) {
    if (!ProviderProfileState._isUsable(profile)) {
      _validation('Select an enabled provider profile first.');
      return false;
    }
    return true;
  }

  bool _supportsDiscovery(ProviderProfile profile) {
    if (profile.providerId == customOpenAiCompatibleProviderId) return true;
    return _registry
            .definitionFor(profile.providerId)
            ?.modelDiscoveryIsAvailable ??
        false;
  }

  String? _validateDraft(ProviderProfileDraft draft) {
    if (draft.displayName.trim().isEmpty) {
      return 'Enter a provider display name.';
    }
    if (draft.timeout.inMilliseconds <= 0) {
      return 'Timeout must be greater than zero.';
    }
    if (draft.providerId != customOpenAiCompatibleProviderId &&
        _registry.definitionFor(draft.providerId) == null) {
      return 'Select a valid provider preset.';
    }
    if (draft.providerId == customOpenAiCompatibleProviderId &&
        draft.endpoint.trim().isEmpty) {
      return 'Enter a custom provider endpoint.';
    }
    final endpoint = ProviderUrlPolicy.parseAndValidate(draft.endpoint);
    if (endpoint case Failure<ProviderUrlValidation>(:final error)) {
      return error.message;
    }
    final names = <String>{};
    for (final name in draft.headers.keys) {
      if (!_validHeader(name) ||
          _sensitiveHeader(name) ||
          !names.add(name.toLowerCase())) {
        return 'Non-secret headers must use unique, non-sensitive names.';
      }
    }
    for (final name in draft.secretHeaderNames) {
      if (!_validHeader(name) || !names.add(name.toLowerCase())) {
        return 'Secret header names must be valid and unique.';
      }
    }
    for (final name in draft.secretHeaderValues.keys) {
      if (!_validHeader(name) ||
          !draft.secretHeaderNames.any(
            (candidate) => candidate.toLowerCase() == name.toLowerCase(),
          )) {
        return 'Secret header names must be valid and unique.';
      }
    }
    return null;
  }

  String? _validateNewSecretValues(
    ProviderProfile? existing,
    String id,
    Iterable<String> names,
    Map<String, String> values,
  ) {
    for (final name in names) {
      final reference = ProviderCredentialReference.secretHeader(id, name);
      // This method is called after the actual ID is known; only the presence
      // rule matters here. The canonical reference comparison happens below.
      if (existing?.secretHeaderCredentialIds[name] == reference) continue;
      if (!values.containsKey(name) || values[name]!.isEmpty) {
        return 'Enter a value for each new secret header.';
      }
    }
    return null;
  }

  List<String> _removedSecretNames(
    ProviderProfile? existing,
    Iterable<String> desired,
    Iterable<String> explicitlyRemoved,
  ) {
    if (existing == null) return const <String>[];
    final desiredNames = desired.map((name) => name.toLowerCase()).toSet();
    final explicitNames = explicitlyRemoved
        .map((name) => name.toLowerCase())
        .toSet();
    return existing.secretHeaderNames
        .where(
          (name) =>
              explicitNames.contains(name.toLowerCase()) ||
              !desiredNames.contains(name.toLowerCase()),
        )
        .toList(growable: false);
  }

  Map<String, String> _normalizedSecretValues(
    Map<String, String> values,
    Iterable<String> names,
  ) {
    final allowed = names.map((name) => name.toLowerCase()).toSet();
    final result = <String, String>{};
    for (final entry in values.entries) {
      final name = entry.key.trim();
      final value = entry.value.trim();
      if (value.isNotEmpty && allowed.contains(name.toLowerCase())) {
        result[name] = value;
      }
    }
    return result;
  }

  List<String> _normalizedModels(Iterable<String> values) {
    final result = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !result.contains(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  List<String> _normalizedHeaderNames(Iterable<String> values) {
    final names = <String>[];
    for (final value in values) {
      final name = value.trim();
      if (name.isNotEmpty &&
          !names.any((item) => item.toLowerCase() == name.toLowerCase())) {
        names.add(name);
      }
    }
    return names;
  }

  List<ModelDescriptor> _uniqueDescriptors(Iterable<ModelDescriptor> models) {
    final ids = <String>{};
    return models.where((model) => ids.add(model.id)).toList(growable: false);
  }

  bool _validHeader(String value) =>
      RegExp(r"^[A-Za-z0-9!#\$%&'*+.^_`|~-]{1,128}$").hasMatch(value);
  bool _sensitiveHeader(String value) {
    final name = value.toLowerCase();
    return name == 'authorization' ||
        name == 'proxy-authorization' ||
        name == 'x-api-key' ||
        name == 'api-key' ||
        name == 'api_key' ||
        name == 'x-auth-token' ||
        name == 'cookie' ||
        name.contains('token') ||
        name.contains('secret') ||
        name.contains('password') ||
        name.contains('apikey');
  }

  void _discoveryUnavailable() => state = state.copyWith(
    action: ProviderProfileAction.idle,
    failure: const ProviderTransportFailure(
      message: 'Discovery unavailable; enter a model ID.',
    ),
    failureMessage: 'Discovery unavailable; enter a model ID.',
  );

  void _validation(String message) => _failure(
    ProviderValidationFailure(message),
    action: ProviderProfileAction.idle,
  );

  void _failure(AppFailure failure, {required ProviderProfileAction action}) {
    state = state.copyWith(
      action: action,
      failure: failure,
      failureMessage: failure.message,
    );
  }

  @override
  void dispose() {
    _discoveryCancellation?.cancel();
    super.dispose();
  }
}
