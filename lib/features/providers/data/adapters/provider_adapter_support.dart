import 'dart:convert';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/data/policy/provider_endpoint_resolver.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/entities/provider_connection_result.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';

/// Shared, protocol-neutral safety boundaries for provider adapters.
abstract base class ProviderAdapterBase implements ModelProviderAdapter {
  ProviderAdapterBase({
    required this.transport,
    required this.credentials,
    required Iterable<String> providerIds,
  }) : providerIds = Set<String>.unmodifiable(providerIds);

  final ProviderHttpTransport transport;
  final CredentialStore credentials;
  final Set<String> providerIds;

  Result<T> validation<T>(String message) =>
      Failure<T>(ProviderValidationFailure(message));

  Result<T> cancelled<T>() => Failure<T>(const ProviderCancellationFailure());

  Result<T>? validateProfile<T>(
    ProviderProfile profile, {
    ModelRequest? request,
  }) {
    if (!providerIds.contains(profile.providerId)) {
      return validation<T>(
        'The provider profile is not compatible with this adapter.',
      );
    }
    if (!profile.enabled) {
      return validation<T>('The provider profile is disabled.');
    }
    if (profile.deletionPending) {
      return validation<T>('The provider profile deletion is pending.');
    }
    if (ProviderUrlPolicy.validate(profile.endpoint)
        is Failure<ProviderUrlValidation>) {
      return validation<T>('The provider endpoint is invalid.');
    }
    if (request != null) {
      if (request.providerId != profile.providerId) {
        return validation<T>(
          'The request provider does not match the profile.',
        );
      }
      if (request.modelId.trim().isEmpty) {
        return validation<T>('A model identifier is required.');
      }
      if (request.messages.isEmpty ||
          request.tools.any((tool) => tool.name.trim().isEmpty)) {
        return validation<T>('The provider request is malformed.');
      }
    }
    return null;
  }

  Future<Result<Map<String, String>>> headersFor(
    ProviderProfile profile, {
    required bool needsApiKey,
    String? apiHeader,
    bool bearerApiKey = false,
    Map<String, String> requiredHeaders = const <String, String>{},
  }) async {
    try {
      final headers = <String, String>{...profile.headers, ...requiredHeaders};
      final secretNames = <String>{
        ...profile.secretHeaderNames,
        ...profile.secretHeaderCredentialIds.keys,
      };
      for (final name in secretNames) {
        final reference =
            profile.secretHeaderCredentialIds[name] ??
            ProviderCredentialReference.secretHeader(profile.id, name);
        if (reference !=
            ProviderCredentialReference.secretHeader(profile.id, name)) {
          return const Failure<Map<String, String>>(
            ProviderCredentialFailure(
              'The provider credential reference is invalid.',
            ),
          );
        }
        final secret = await credentials.read(reference);
        if (secret is Failure<String?>) {
          return const Failure<Map<String, String>>(
            ProviderCredentialFailure(
              'A required provider credential is unavailable.',
            ),
          );
        }
        final secretValue = (secret as Success<String?>).value;
        if (secretValue == null || secretValue.isEmpty) {
          return const Failure<Map<String, String>>(
            ProviderCredentialFailure(
              'A required provider credential is unavailable.',
            ),
          );
        }
        headers[name] = secretValue;
      }
      if (!needsApiKey) return Success<Map<String, String>>(headers);

      final key = await apiKeyFor(profile);
      if (key is Failure<String>) {
        return Failure<Map<String, String>>(key.error);
      }
      if (apiHeader != null) {
        final value = (key as Success<String>).value;
        headers[apiHeader] = bearerApiKey ? 'Bearer $value' : value;
      }
      return Success<Map<String, String>>(headers);
    } on ArgumentError {
      return const Failure<Map<String, String>>(
        ProviderCredentialFailure(
          'The provider credential reference is invalid.',
        ),
      );
    } catch (_) {
      return const Failure<Map<String, String>>(
        ProviderCredentialFailure('Unable to read provider credentials.'),
      );
    }
  }

  Future<Result<String>> apiKeyFor(ProviderProfile profile) async {
    try {
      final expected = ProviderCredentialReference.apiKey(profile.id);
      if (profile.credentialId != null && profile.credentialId != expected) {
        return const Failure<String>(
          ProviderCredentialFailure(
            'The provider credential reference is invalid.',
          ),
        );
      }
      final key = await credentials.read(expected);
      if (key is Failure<String?>) {
        return const Failure<String>(
          ProviderCredentialFailure(
            'A required provider credential is unavailable.',
          ),
        );
      }
      final value = (key as Success<String?>).value;
      if (value == null || value.isEmpty) {
        return const Failure<String>(
          ProviderCredentialFailure(
            'A required provider credential is unavailable.',
          ),
        );
      }
      return Success<String>(value);
    } on ArgumentError {
      return const Failure<String>(
        ProviderCredentialFailure(
          'The provider credential reference is invalid.',
        ),
      );
    } catch (_) {
      return const Failure<String>(
        ProviderCredentialFailure('Unable to read provider credentials.'),
      );
    }
  }

  Uri endpoint(ProviderProfile profile, String relative) =>
      ProviderEndpointResolver.resolve(profile.endpoint, relative);

  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request,
    CancellationToken token,
  ) async {
    try {
      token.throwIfCancelled();
      return await transport.send(request, token: token);
    } on CancelledException {
      return const Failure<ProviderHttpResponse>(ProviderCancellationFailure());
    } catch (_) {
      return const Failure<ProviderHttpResponse>(ProviderTransportFailure());
    }
  }

  @override
  Future<Result<ProviderConnectionResult>> testConnection(
    ProviderProfile profile,
    CancellationToken token,
  ) async {
    final discovered = await discoverModels(profile, token);
    if (discovered is Failure<List<ModelDescriptor>>) {
      return Failure<ProviderConnectionResult>(discovered.error);
    }
    return const Success<ProviderConnectionResult>(
      ProviderConnectionResult(isConnected: true),
    );
  }

  Map<String, Object?>? objectMap(Object? value) {
    if (value is! Map) return null;
    final converted = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      converted[entry.key as String] = entry.value;
    }
    return converted;
  }

  Map<String, Object?>? arguments(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    return objectMap(value);
  }

  NormalizedModelToolCall? toolCall({
    required Object? id,
    required Object? name,
    required Object? input,
  }) {
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    final parsed = arguments(input);
    if (parsed == null) return null;
    return NormalizedModelToolCall(id: id, name: name, arguments: parsed);
  }

  List<ModelDescriptor> manualModels(ProviderProfile profile) => profile
      .manualModelIds
      .where((id) => id.trim().isNotEmpty)
      .toSet()
      .map(
        (id) => ModelDescriptor(
          id: id,
          providerId: profile.providerId,
          displayName: id,
        ),
      )
      .toList(growable: false);
}
