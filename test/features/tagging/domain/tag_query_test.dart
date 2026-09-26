import 'package:clipmind/features/projects/domain/entities/media_asset.dart';
import 'package:clipmind/features/tagging/domain/tag_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes text and searches display names, never source paths', () {
    final assets = [
      _asset(
        id: 'one',
        displayName: 'Summer TRIP.mov',
        sourcePath: '/private/holiday/one.mov',
      ),
      _asset(
        id: 'two',
        displayName: 'Interview.mov',
        sourcePath: '/private/summer-trip/two.mov',
      ),
    ];

    final query = TagQuery(text: '  trip  ');

    expect(query.text, 'trip');
    expect(query.filter(assets).map((asset) => asset.id), ['one']);
    expect(TagQuery(text: 'holiday').filter(assets), isEmpty);
  });

  test(
    'requires every selected tag while empty filters match all source assets',
    () {
      final assets = [
        _asset(id: 'one', displayName: 'One', tagIds: {'warm', 'featured'}),
        _asset(id: 'two', displayName: 'Two', tagIds: {'warm'}),
        _asset(id: 'three', displayName: 'Three', tagIds: {'featured'}),
      ];

      expect(
        TagQuery(
          selectedTagIds: {'warm', 'featured'},
        ).filter(assets).map((asset) => asset.id),
        ['one'],
      );
      expect(TagQuery().filter(assets).map((asset) => asset.id), [
        'one',
        'two',
        'three',
      ]);
    },
  );

  test(
    'defensively owns tag selection and preserves source order without mutation',
    () {
      final selection = <String>{'warm'};
      final assets = [
        _asset(id: 'first', displayName: 'First', tagIds: {'warm'}),
        _asset(id: 'second', displayName: 'Second', tagIds: {'warm'}),
      ];
      final sourceIds = assets.map((asset) => asset.id).toList();
      final query = TagQuery(selectedTagIds: selection);

      selection
        ..clear()
        ..add('other');

      expect(query.selectedTagIds, {'warm'});
      expect(() => query.selectedTagIds.add('other'), throwsUnsupportedError);
      expect(query.filter(assets).map((asset) => asset.id), [
        'first',
        'second',
      ]);
      expect(assets.map((asset) => asset.id), sourceIds);
      expect(assets.first.tagIds, {'warm'});
    },
  );
}

MediaAsset _asset({
  required String id,
  required String displayName,
  String sourcePath = '/media/file.mov',
  Set<String> tagIds = const {},
}) => MediaAsset(
  id: id,
  sourcePath: sourcePath,
  displayName: displayName,
  durationMs: 1000,
  tagIds: tagIds,
);
