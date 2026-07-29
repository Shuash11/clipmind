import 'provider_capabilities.dart';

enum ProviderProtocol { compatible, anthropic, gemini, ollama }

/// A provider preset.  Its identifier identifies the service, never a model.
final class ProviderDefinition {
  const ProviderDefinition({
    required this.id,
    required this.displayName,
    required this.baseUri,
    required this.protocol,
    required this.capabilities,
    this.modelDiscoveryRelativePath,
  });

  final String id;
  final String displayName;
  final Uri baseUri;
  final ProviderProtocol protocol;
  final ProviderCapabilities capabilities;

  /// Null means the provider has deliberately no discovery endpoint.
  final String? modelDiscoveryRelativePath;

  bool get modelDiscoveryIsAvailable => modelDiscoveryRelativePath != null;
}
