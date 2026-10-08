import 'dart:io';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/project_file_store.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 9 durability: [ProjectFileStore.write] must be atomic (`.tmp` +
/// flush + rename) and must surface failures as [PersistenceFailure] instead
/// of swallowing them behind a `false` return.
void main() {
  late Directory tempDir;
  late ProjectFileStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clipmind_file_store_');
    store = ProjectFileStore();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('write persists the document, leaves no temp file, and read '
      'round-trips', () async {
    final project = _project(name: 'Round Trip', tracks: _tracks);

    await store.write(project, tempDir.path);

    final target = File('${tempDir.path}/p1.cmproj');
    expect(target.existsSync(), isTrue);
    expect(_tempFiles(tempDir.path), isEmpty);

    final reloaded = await store.read(target.path);
    expect(reloaded, isNotNull);
    expect(reloaded!.id, 'p1');
    expect(reloaded.name, 'Round Trip');
    expect(reloaded.durationMs, 60000);
    expect(reloaded.sourceMediaPaths, ['/media/a.mp4']);
    expect(reloaded.tracks.single.clips.single.id, 'c1');
    expect(reloaded.tracks.single.clips.single.endMs, 60000);
  });

  test('write over the same id replaces the document (v2 wins) atomically',
      () async {
    await store.write(_project(name: 'v1'), tempDir.path);
    await store.write(_project(name: 'v2'), tempDir.path);

    final reloaded = await store.read('${tempDir.path}/p1.cmproj');
    expect(reloaded, isNotNull);
    expect(reloaded!.name, 'v2');
    expect(_tempFiles(tempDir.path), isEmpty);
  });

  test('write throws PersistenceFailure when the target path is a directory',
      () async {
    final blockedTarget = Directory('${tempDir.path}/p1.cmproj')
      ..createSync(recursive: true);

    await expectLater(
      store.write(_project(), tempDir.path),
      throwsA(isA<PersistenceFailure>()),
    );

    expect(blockedTarget.existsSync(), isTrue);
    expect(blockedTarget.listSync(), isEmpty);
    expect(_tempFiles(tempDir.path), isEmpty);
  });

  test('write throws PersistenceFailure when the directory cannot be created',
      () async {
    final blocker = File('${tempDir.path}/blocker')
      ..writeAsStringSync('file');
    final nested = '${blocker.path}${Platform.pathSeparator}projects';

    await expectLater(
      store.write(_project(), nested),
      throwsA(isA<PersistenceFailure>()),
    );

    expect(blocker.existsSync(), isTrue);
    expect(blocker.readAsStringSync(), 'file');
  });
}

Project _project({String name = 'Project One', List<Track> tracks = const []}) {
  final timestamp = DateTime(2026, 10, 8, 9, 30);
  return Project(
    id: 'p1',
    name: name,
    createdAt: timestamp,
    updatedAt: timestamp,
    sourceMediaPaths: const ['/media/a.mp4'],
    tracks: tracks,
    durationMs: 60000,
  );
}

const _tracks = [
  Track(
    id: 't1',
    type: TrackType.video,
    label: 'Video',
    clips: [
      Clip(
        id: 'c1',
        trackId: 't1',
        sourcePath: '/media/a.mp4',
        startMs: 0,
        endMs: 60000,
      ),
    ],
  ),
];

List<String> _tempFiles(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<File>()
      .map((file) => file.path)
      .where((path) => path.endsWith('.tmp'))
      .toList();
}
