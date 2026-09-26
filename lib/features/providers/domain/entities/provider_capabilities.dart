final class ProviderCapabilities {
  const ProviderCapabilities({
    this.supportsModelDiscovery = false,
    this.supportsTools = false,
    this.supportsStreaming = false,
  });

  final bool supportsModelDiscovery;
  final bool supportsTools;
  final bool supportsStreaming;
}
