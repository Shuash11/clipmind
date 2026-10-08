import 'dart:io';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// path_provider stub: `getApplicationSupportDirectory` returns
/// [appSupportPath] so the real [ProjectRepository] writes its `.cmproj`
/// file into the test's temp tree instead of the host app-support dir
/// (mirrors `test/integration/core_path_seam_test.dart`).
void _mockPathProvider(String appSupportPath) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return appSupportPath;
          }
          return null;
        },
      );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
}

/// Cycle 9 durability at the repository seam: a successful save lands the
/// file *and* the index row; a failed file write throws and leaves no
/// phantom row behind (restart honesty).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appSupport;
  late AppDatabase db;
  late ProjectRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clipmind_repo_save_');
    appSupport = Directory('${tempDir.path}/app_support')..createSync();
    _mockPathProvider(appSupport.path);
    db = AppDatabase(NativeDatabase.memory());
    repository = ProjectRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('successful save writes the file and the index row', () async {
    final project = _project();

    await repository.save(project);

    final path = await db.getProjectPath(project.id);
    expect(path, isNotNull);
    expect(path, endsWith('${project.id}.cmproj'));
    expect(File(path!).existsSync(), isTrue);

    final reloaded = await repository.loadFromId(project.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.tracks.single.clips.single.sourcePath, '/media/a.mp4');
    expect(reloaded.tracks.single.clips.single.endMs, 60000);

    expect(_tempFiles('${appSupport.path}/projects'), isEmpty);
  });

  test('failed save throws PersistenceFailure and leaves no phantom index row',
      () async {
    final project = _project(id: 'p_blocked');
    final blocked = Directory(
      '${appSupport.path}/projects/${project.id}.cmproj',
    )..createSync(recursive: true);

    await expectLater(
      repository.save(project),
      throwsA(isA<PersistenceFailure>()),
    );

    expect(await db.getProjectPath(project.id), isNull);
    expect(await db.getProject(project.id), isNull);
    expect(blocked.existsSync(), isTrue);
    expect(_tempFiles('${appSupport.path}/projects'), isEmpty);
  });
}

Project _project({String id = 'p1'}) {
  final timestamp = DateTime(2026, 10, 8, 9, 30);
  return Project(
    id: id,
    name: 'Persisted',
    createdAt: timestamp,
    updatedAt: timestamp,
    sourceMediaPaths: const ['/media/a.mp4'],
    tracks: const [
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
    ],
    durationMs: 60000,
  );
}

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
