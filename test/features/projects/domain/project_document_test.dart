import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import '../support/project_test_data.dart';

void main() {
  test(
    'snapshot/document/history JSON round trip contains no nested document',
    () {
      final before = stateWithOneClip();
      final after = before.copyWith(
        overlays: [textOverlayFixture('overlay-1')],
      );
      final document = documentWithOneClip(
        state: after,
        history: [recordFor(before: before, after: after)],
        historyCursor: 0,
      );
      final codec = ProjectDocumentCodec();
      final encoded = codec.encodeJson(document);
      final reopened =
          (codec.decodeJson(encoded) as Success<ProjectDocument>).value;
      expect(reopened.currentState.overlays.single.id, 'overlay-1');
      expect(
        reopened.history.single.beforeState.tracks.single.clips.single.id,
        'clip-1',
      );
      expect(
        jsonDecode(encoded).toString(),
        isNot(contains('ProjectDocument')),
      );
    },
  );

  test(
    'history records carry snapshots rather than document or nested history',
    () {
      final json = ProjectDocumentCodec().encodeJson(
        documentWithOneClip(
          history: [
            recordFor(before: stateWithOneClip(), after: stateWithOneClip()),
          ],
          historyCursor: 0,
        ),
      );
      final decoded = jsonDecode(json) as Map<String, Object?>;
      final record =
          (decoded['history'] as List<Object?>).single as Map<String, Object?>;
      expect(record.containsKey('document'), isFalse);
      expect(
        (record['beforeState'] as Map<String, Object?>).containsKey('history'),
        isFalse,
      );
      expect(
        (record['afterState'] as Map<String, Object?>).containsKey('history'),
        isFalse,
      );
    },
  );
}
