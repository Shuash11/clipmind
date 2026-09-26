final class ModelDescriptor {
  ModelDescriptor({
    required this.id,
    required this.providerId,
    required this.displayName,
    Iterable<String> capabilities = const <String>[],
  }) : capabilities = List.unmodifiable(List<String>.from(capabilities));

  final String id;
  final String providerId;
  final String displayName;
  final List<String> capabilities;
}
