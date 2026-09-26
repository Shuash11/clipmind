import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderProfileForm extends ConsumerStatefulWidget {
  const ProviderProfileForm({this.profile, this.onRendered, super.key});

  final ProviderProfile? profile;
  final VoidCallback? onRendered;

  @override
  ConsumerState<ProviderProfileForm> createState() =>
      _ProviderProfileFormState();
}

class _ProviderProfileFormState extends ConsumerState<ProviderProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _timeout;
  late final TextEditingController _apiKey;
  late final TextEditingController _headers;
  late final TextEditingController _manualModels;
  late final TextEditingController _selectedModel;
  late final List<_SecretHeaderRow> _secretRows;
  final Set<String> _removedSecretHeaders = <String>{};
  late String _providerId;
  late bool _enabled;
  bool _removeApiKey = false;
  bool _rendered = false;

  @override
  void didUpdateWidget(covariant ProviderProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id) _rendered = false;
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _providerId = profile?.providerId ?? 'openai';
    _enabled = profile?.enabled ?? true;
    _name = TextEditingController(text: profile?.displayName ?? '');
    _endpoint = TextEditingController(
      text: profile?.endpoint.toString() ?? _presetEndpoint(_providerId),
    );
    _timeout = TextEditingController(
      text: '${profile?.timeout.inSeconds ?? 30}',
    );
    _apiKey = TextEditingController();
    _headers = TextEditingController(
      text: _encodeHeaders(profile?.headers ?? const <String, String>{}),
    );
    _manualModels = TextEditingController(
      text: profile?.manualModelIds.join(', ') ?? '',
    );
    _selectedModel = TextEditingController(
      text: profile?.selectedModelId ?? '',
    );
    _secretRows = <_SecretHeaderRow>[
      for (final name in profile?.secretHeaderNames ?? const <String>[])
        _SecretHeaderRow(existingName: name),
    ];
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _endpoint,
      _timeout,
      _apiKey,
      _headers,
      _manualModels,
      _selectedModel,
    ]) {
      controller.dispose();
    }
    for (final row in _secretRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(providerRegistryProvider);
    final state = ref.watch(providerProfileNotifierProvider);
    final definitions = registry.definitions.toList(growable: false);
    final pending = widget.profile?.deletionPending ?? false;
    final canRunActions = !pending && _enabled && widget.profile != null;
    final isCustom = _providerId == customOpenAiCompatibleProviderId;
    _scheduleRendered();
    return KeyedSubtree(
      key: const ValueKey('provider-profile-form'),
      child: Container(
        key: isCustom ? const ValueKey('custom-provider-form') : null,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              _FormHeader(profile: widget.profile),
              const SizedBox(height: 22),
              TextFormField(
                key: const ValueKey('provider-display-name'),
                controller: _name,
                enabled: !pending,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a provider display name.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'provider-preset-${widget.profile?.id ?? 'new'}-$_providerId',
                ),
                initialValue: _providerId,
                decoration: const InputDecoration(labelText: 'Provider preset'),
                items: <DropdownMenuItem<String>>[
                  ...definitions.map(
                    (definition) => DropdownMenuItem<String>(
                      value: definition.id,
                      child: Text(definition.displayName),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: customOpenAiCompatibleProviderId,
                    child: Text('Custom OpenAI-compatible'),
                  ),
                ],
                onChanged: pending
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _providerId = value;
                          if (value == customOpenAiCompatibleProviderId) {
                            _endpoint.clear();
                          } else {
                            _endpoint.text = _presetEndpoint(
                              value,
                              definitions,
                            );
                          }
                        });
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('provider-endpoint'),
                controller: _endpoint,
                enabled: !pending,
                decoration: InputDecoration(
                  labelText: isCustom ? 'Custom endpoint' : 'Endpoint',
                ),
                validator: _endpointValidation,
                onChanged: (_) => setState(() {}),
              ),
              if (_isLocalHttpWarning)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Local HTTP is not encrypted.',
                    style: TextStyle(color: ClipMindColors.statusWarning),
                  ),
                ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('provider-timeout'),
                controller: _timeout,
                keyboardType: TextInputType.number,
                enabled: !pending,
                decoration: const InputDecoration(
                  labelText: 'Timeout (seconds)',
                ),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                    ? 'Timeout must be greater than zero.'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                subtitle: const Text(
                  'Disabled profiles cannot be active or make requests.',
                ),
                value: _enabled,
                onChanged: pending
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              const Divider(height: 30),
              Text(
                'CREDENTIALS',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('provider-api-key'),
                controller: _apiKey,
                obscureText: true,
                enabled: !pending,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  helperText:
                      'Leave blank to keep existing secure storage value.',
                ),
              ),
              if (widget.profile?.credentialId != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _removeApiKey,
                  onChanged: pending
                      ? null
                      : (value) =>
                            setState(() => _removeApiKey = value ?? false),
                  title: const Text('Remove saved API key'),
                ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('provider-headers'),
                controller: _headers,
                enabled: !pending,
                decoration: const InputDecoration(
                  labelText: 'Non-secret headers',
                  helperText:
                      'One Name: Value pair per line. Do not enter tokens here.',
                ),
              ),
              const SizedBox(height: 16),
              _SecretHeaderEditor(
                rows: _secretRows,
                enabled: !pending,
                onAdd: _addSecretRow,
                onRemove: _removeSecretRow,
              ),
              const Divider(height: 30),
              Text('MODELS', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('manual-models'),
                controller: _manualModels,
                enabled: !pending,
                decoration: const InputDecoration(
                  labelText: 'Manual model IDs',
                  helperText: 'Comma separated fallback model IDs.',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('selected-model'),
                controller: _selectedModel,
                enabled: !pending,
                decoration: const InputDecoration(
                  labelText: 'Selected model ID (optional)',
                ),
              ),
              if (state.failureMessage != null)
                _Notice(message: state.failureMessage!, error: true),
              if (state.connectionMessage != null)
                _Notice(message: state.connectionMessage!),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    key: const ValueKey('save-provider-profile'),
                    onPressed:
                        pending || state.action == ProviderProfileAction.saving
                        ? null
                        : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('activate-provider-profile'),
                    onPressed: canRunActions
                        ? () => ref
                              .read(providerProfileNotifierProvider.notifier)
                              .activateProfile(widget.profile!.id)
                        : null,
                    icon: const Icon(Icons.radio_button_checked),
                    label: const Text('Make active'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('test-provider-connection'),
                    onPressed: canRunActions
                        ? () => ref
                              .read(providerProfileNotifierProvider.notifier)
                              .testConnection(widget.profile!.id)
                        : null,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Test connection'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('discover-provider-models'),
                    onPressed: canRunActions
                        ? () => ref
                              .read(providerProfileNotifierProvider.notifier)
                              .discoverModels(widget.profile!.id)
                        : null,
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Discover models'),
                  ),
                  if (widget.profile != null)
                    OutlinedButton.icon(
                      key: const ValueKey('delete-provider-profile'),
                      onPressed: pending
                          ? null
                          : () => ref
                                .read(providerProfileNotifierProvider.notifier)
                                .deleteProfile(widget.profile!.id),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ClipMindColors.statusError,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleRendered() {
    if (_rendered) return;
    _rendered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRendered?.call();
    });
  }

  void _addSecretRow() => setState(() => _secretRows.add(_SecretHeaderRow()));

  void _removeSecretRow(_SecretHeaderRow row) {
    setState(() {
      if (row.existingName != null) {
        _removedSecretHeaders.add(row.existingName!);
      }
      _secretRows.remove(row);
      row.dispose();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final headers = _parseHeaders(_headers.text);
    if (headers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Headers must use Name: Value pairs.')),
      );
      return;
    }
    final secretNames = <String>[];
    final secretValues = <String, String>{};
    final currentNames = <String>{};
    for (final row in _secretRows) {
      final name = row.name.text.trim();
      if (name.isEmpty) continue;
      secretNames.add(name);
      currentNames.add(name.toLowerCase());
      final value = row.value.text;
      if (value.trim().isNotEmpty) secretValues[name] = value;
      if (row.existingName != null &&
          row.existingName!.toLowerCase() != name.toLowerCase()) {
        _removedSecretHeaders.add(row.existingName!);
      }
    }
    final removed = _removedSecretHeaders
        .where((name) => !currentNames.contains(name.toLowerCase()))
        .toList(growable: false);
    await ref
        .read(providerProfileNotifierProvider.notifier)
        .saveProfile(
          ProviderProfileDraft(
            id: widget.profile?.id,
            providerId: _providerId,
            displayName: _name.text,
            endpoint: _endpoint.text,
            enabled: _enabled,
            timeout: Duration(seconds: int.parse(_timeout.text)),
            headers: headers,
            secretHeaderNames: secretNames,
            secretHeaderValues: secretValues,
            apiKey: _apiKey.text,
            removeApiKey: _removeApiKey,
            removeSecretHeaders: removed,
            manualModelIds: _split(_manualModels.text),
            selectedModelId: _selectedModel.text,
          ),
        );
    if (!mounted) return;
    _apiKey.clear();
    for (final row in _secretRows) {
      row.value.clear();
    }
  }

  String _presetEndpoint(
    String providerId, [
    Iterable<ProviderDefinition>? definitions,
  ]) {
    final source = definitions ?? ProviderCatalog.presets;
    for (final definition in source) {
      if (definition.id == providerId) return definition.baseUri.toString();
    }
    return '';
  }

  bool get _isLocalHttpWarning {
    final result = ProviderUrlPolicy.parseAndValidate(_endpoint.text);
    return result is Success<ProviderUrlValidation> &&
        result.value.warnings.contains(ProviderUrlWarning.insecureLocalHttp);
  }

  String? _endpointValidation(String? value) {
    final result = ProviderUrlPolicy.parseAndValidate(value ?? '');
    return result is Failure<ProviderUrlValidation>
        ? result.error.message
        : null;
  }

  List<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Map<String, String>? _parseHeaders(String value) {
    final output = <String, String>{};
    for (final line in value.split('\n')) {
      if (line.trim().isEmpty) continue;
      final split = line.indexOf(':');
      if (split < 1) return null;
      output[line.substring(0, split).trim()] = line
          .substring(split + 1)
          .trim();
    }
    return output;
  }

  String _encodeHeaders(Map<String, String> value) =>
      value.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.profile});

  final ProviderProfile? profile;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              profile == null ? 'NEW PROFILE' : 'PROFILE CONFIGURATION',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              profile?.displayName ?? 'Add provider profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      if (profile != null) _StatusChip(profile: profile!),
    ],
  );
}

class _SecretHeaderEditor extends StatelessWidget {
  const _SecretHeaderEditor({
    required this.rows,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_SecretHeaderRow> rows;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<_SecretHeaderRow> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Secret headers',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            key: const ValueKey('add-secret-header'),
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add header'),
          ),
        ],
      ),
      const Text(
        'Values are stored securely and are always blank when reopened.',
        style: TextStyle(color: ClipMindColors.textMuted, fontSize: 11),
      ),
      const SizedBox(height: 8),
      for (var index = 0; index < rows.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey('secret-header-name-$index'),
                  controller: rows[index].name,
                  enabled: enabled,
                  decoration: const InputDecoration(labelText: 'Header name'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: ValueKey('secret-header-value-$index'),
                  controller: rows[index].value,
                  obscureText: true,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    helperText: 'Blank keeps existing value',
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('remove-secret-header-$index'),
                tooltip: 'Remove secret header',
                onPressed: enabled ? () => onRemove(rows[index]) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        ),
    ],
  );
}

final class _SecretHeaderRow {
  _SecretHeaderRow({this.existingName})
    : name = TextEditingController(text: existingName ?? ''),
      value = TextEditingController();

  final String? existingName;
  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.profile});

  final ProviderProfile profile;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      profile.deletionPending
          ? 'PENDING'
          : profile.enabled
          ? 'ENABLED'
          : 'DISABLED',
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      message,
      style: TextStyle(
        color: error ? ClipMindColors.statusError : ClipMindColors.statusReady,
      ),
    ),
  );
}
