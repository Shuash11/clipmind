import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clipmind/data/services/updates/update_result_reader.dart';

void main() {
  late Directory appSupport;
  late UpdateResultReader reader;

  setUp(() async {
    appSupport = await Directory.systemTemp.createTemp('update_reader_test_');
    reader = UpdateResultReader(appSupportOverride: appSupport.path);
  });

  tearDown(() async {
    try {
      await appSupport.delete(recursive: true);
    } catch (_) {}
  });

  String resultPath() =>
      '${appSupport.path.replaceAll('\\', '/')}/updates/update-result.json';

  Future<void> writeResult(Map<String, dynamic> json) async {
    await Directory('${appSupport.path}/updates').create(recursive: true);
    await File(resultPath()).writeAsString(jsonEncode(json));
  }

  test('missing result file is a no-op', () async {
    final result = await reader.consume(currentVersion: '1.36.3');
    expect(result, isNull);
  });

  test('failed result surfaces with its reason and is consumed', () async {
    await writeResult({
      'status': 'failed',
      'reason': 'Installer exited with code 5',
      'expectedVersion': '1.36.3',
      'finishedAt': '2026-10-04T16:00:00.000Z',
    });

    final result = await reader.consume(currentVersion: '1.36.3');

    expect(result, isNotNull);
    expect(result!.kind, equals(UpdateResultKind.failed));
    expect(result.message, equals('Installer exited with code 5'));
    // consume() deletes after read: the next launch sees nothing.
    expect(File(resultPath()).existsSync(), isFalse);
  });

  test('success with matching version is clean and the file is deleted',
      () async {
    await writeResult({
      'status': 'success',
      'expectedVersion': '1.36.3',
      'finishedAt': '2026-10-04T16:00:00.000Z',
    });

    final result = await reader.consume(currentVersion: '1.36.3');

    expect(result, isNotNull);
    expect(result!.kind, equals(UpdateResultKind.success));
    expect(result.message, isNull);
    expect(File(resultPath()).existsSync(), isFalse);
  });

  test('success with a version mismatch surfaces the warning', () async {
    await writeResult({
      'status': 'success',
      'expectedVersion': '1.36.4',
      'finishedAt': '2026-10-04T16:00:00.000Z',
    });

    final result = await reader.consume(currentVersion: '1.36.3');

    expect(result, isNotNull);
    expect(result!.kind, equals(UpdateResultKind.versionMismatch));
    expect(result.message, contains("you're running version 1.36.3"));
    expect(File(resultPath()).existsSync(), isFalse);
  });

  test('unrecognized status is a no-op', () async {
    await writeResult({'status': 'weird'});

    final result = await reader.consume(currentVersion: '1.36.3');

    expect(result, isNull);
    expect(File(resultPath()).existsSync(), isFalse);
  });
}
