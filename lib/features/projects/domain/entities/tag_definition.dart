final class TagDefinition {
  const TagDefinition({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final String color;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': color};

  factory TagDefinition.fromJson(Map<String, Object?> json) => TagDefinition(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is TagDefinition &&
      id == other.id &&
      name == other.name &&
      color == other.color;

  @override
  int get hashCode => Object.hash(id, name, color);
}
