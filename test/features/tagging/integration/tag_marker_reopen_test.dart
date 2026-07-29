import 'dart:convert';
import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixtureJson() => File(
  'test/fixtures/projects/schema2_tags_markers.cmproj',
).readAsStringSync();

void main() {
  test(
    'schema-two tags and markers fixture reopens without recursive history',
    () {
      final codec = ProjectDocumentCodec();
      final decoded = codec.decodeJson(_fixtureJson());

      expect(decoded, isA<Success<ProjectDocument>>());
      final document = (decoded as Success<ProjectDocument>).value;
      expect(document.schemaVersion, 2);
      expect(document.currentState.tags, hasLength(2));
      expect(document.currentState.tags.first.color, '#2255AA');
      expect(document.currentState.assetById('asset-1')!.tagIds, {'tag-1'});
      expect(document.currentState.tracks.single.clips.single.tagIds, {
        'tag-1',
      });
      expect(document.currentState.markers, hasLength(2));
      expect(document.currentState.markers[0].atMs, 240);
      expect(document.currentState.markers[0].startMs, isNull);
      expect(document.currentState.markers[1].startMs, 400);
      expect(document.currentState.markers[1].endMs, 900);
      expect(
        document.currentState.markers[1].endMs! -
            document.currentState.markers[1].startMs!,
        greaterThan(0),
      );
      expect(document.history, hasLength(1));
      expect(document.history.single.planId, 'manual-tag-update-1');
      expect(document.history.single.commands.single.type, 'update_tag');
      expect(document.history.single.commands.single.targetIds, ['tag-1']);

      final encoded =
          jsonDecode(codec.encodeJson(document)) as Map<String, dynamic>;
      final reopened = codec.decodeJson(jsonEncode(encoded));
      expect(reopened, isA<Success<ProjectDocument>>());
      expect((reopened as Success<ProjectDocument>).value, document);

      final record =
          (encoded['history'] as List<dynamic>).single as Map<String, dynamic>;
      for (final key in ['beforeState', 'afterState']) {
        final snapshot = record[key] as Map<String, dynamic>;
        expect(snapshot.keys.toSet(), {
          'assets',
          'tracks',
          'tags',
          'markers',
          'overlays',
        });
        expect(_containsKey(snapshot, 'history'), isFalse);
        expect(_containsKey(snapshot, 'currentState'), isFalse);
      }
    },
  );
}

bool _containsKey(Object? value, String expectedKey) {
  if (value is Map) {
    if (value.containsKey(expectedKey)) return true;
    return value.values.any((nested) => _containsKey(nested, expectedKey));
  }
  if (value is Iterable) {
    return value.any((nested) => _containsKey(nested, expectedKey));
  }
  return false;
}
