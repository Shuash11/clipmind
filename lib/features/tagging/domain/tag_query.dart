import 'package:clipmind/features/projects/domain/entities/media_asset.dart';

final class TagQuery {
  TagQuery({String text = '', Set<String> selectedTagIds = const {}})
    : text = text.trim().toLowerCase(),
      selectedTagIds = Set.unmodifiable(selectedTagIds);

  final String text;
  final Set<String> selectedTagIds;

  List<MediaAsset> filter(Iterable<MediaAsset> assets) {
    final matches = <MediaAsset>[];
    for (final asset in assets) {
      final matchesText =
          text.isEmpty || asset.displayName.toLowerCase().contains(text);
      final matchesTags = asset.tagIds.containsAll(selectedTagIds);
      if (matchesText && matchesTags) matches.add(asset);
    }
    return List.unmodifiable(matches);
  }
}
