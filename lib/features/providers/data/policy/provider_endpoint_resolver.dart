final class ProviderEndpointResolver {
  ProviderEndpointResolver._();

  /// Resolves without allowing a relative path to discard a provider base prefix.
  static Uri resolve(Uri base, String relative) {
    final normalizedBase = base.replace(
      path: base.path.endsWith('/') ? base.path : '${base.path}/',
      queryParameters: const <String, String>{},
      fragment: '',
    );
    final normalizedRelative = relative.replaceFirst(RegExp(r'^/+'), '');
    return normalizedBase.resolve(normalizedRelative);
  }
}
