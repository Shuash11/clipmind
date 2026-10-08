import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clipmind/data/services/import/url_import_service.dart';

/// Cycle 10 seam: direct-URL import against a real loopback HTTP server,
/// real dio, and real file IO.
///
/// Four behaviors unit mocks cannot prove end to end:
///  (a) a `filename*` Content-Disposition drives the real decoded basename
///      and the exact bytes land on disk;
///  (b) a `text/html` page is rejected with the typed message and no file;
///  (c) two consecutive imports land in distinct files, both intact
///      (the silent-overwrite regression);
///  (d) cancel mid-stream leaves no partial file or folder.
void main() {
  late Directory importsDir;
  late HttpServer server;
  late FutureOr<void> Function(HttpRequest request) handle;

  setUp(() async {
    importsDir = await Directory.systemTemp.createTemp('url_import_seam_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await handle(request);
      } catch (_) {
        // Client hung up mid-response (cancel scenarios): ignore.
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    try {
      await importsDir.delete(recursive: true);
    } catch (_) {}
  });

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  Future<({String? path, List<String> errors})> collect(
    UrlImportService service,
    String targetUrl,
  ) async {
    final future = service.import(targetUrl, importsDir.path);
    final errors = <String>[];
    final sub = service.errors.listen(errors.add);
    final path = await future;
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return (path: path, errors: errors);
  }

  test(
    '(a) filename* drives the real decoded basename and exact bytes',
    () async {
      final payload = List<int>.generate(256, (i) => i);
      handle = (request) async {
        request.response.headers.set(
          'content-disposition',
          "attachment; filename*=UTF-8''caf%C3%A9%20clip.mp4",
        );
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
      };

      final service = UrlImportService();
      final outcome = await collect(service, url('/cafe'));

      expect(outcome.errors, isEmpty);
      expect(outcome.path, isNotNull);
      final file = File(outcome.path!);
      expect(file.existsSync(), isTrue);
      final normalized = outcome.path!.replaceAll('\\', '/');
      final normalizedDir = importsDir.path.replaceAll('\\', '/');
      expect(normalized, startsWith('$normalizedDir/'));
      expect(normalized.split('/').last, 'café clip.mp4');
      expect(await file.readAsBytes(), equals(payload));
    },
  );

  test('(b) a text/html page is rejected with no file left behind', () async {
    handle = (request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.add(
        utf8.encode('<!DOCTYPE html><html><body>Sign in</body></html>'),
      );
      await request.response.close();
    };

    final service = UrlImportService();
    final outcome = await collect(service, url('/page'));

    expect(outcome.path, isNull);
    expect(outcome.errors, equals([UrlImportService.notVideoMessage]));
    expect(
      importsDir.listSync(),
      isEmpty,
      reason: 'a rejected web page must leave no file or folder',
    );
  });

  test('(c) two consecutive imports land in distinct intact files', () async {
    final firstBytes = List<int>.generate(64, (i) => i);
    final secondBytes = List<int>.generate(64, (i) => 255 - i);
    handle = (request) async {
      final bytes = request.uri.path == '/first' ? firstBytes : secondBytes;
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.add(bytes);
      await request.response.close();
    };

    final service = UrlImportService();
    final first = await collect(service, url('/first'));
    final second = await collect(service, url('/second'));

    expect(first.path, isNotNull);
    expect(second.path, isNotNull);
    expect(first.path, isNot(equals(second.path)));
    // Distinct uuid folders plus the re-read proving no overwrite.
    expect(
      _parentName(first.path!),
      isNot(equals(_parentName(second.path!))),
    );
    expect(await File(first.path!).readAsBytes(), equals(firstBytes));
    expect(await File(second.path!).readAsBytes(), equals(secondBytes));
  });

  test('(d) cancel mid-stream leaves no partial file', () async {
    const chunkSize = 32 * 1024;
    const chunkCount = 64;
    handle = (request) async {
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.contentLength = chunkSize * chunkCount;
      final chunk = List<int>.filled(chunkSize, 7);
      for (var i = 0; i < chunkCount; i++) {
        request.response.add(chunk);
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await request.response.close();
    };

    final service = UrlImportService();
    final future = service.import(url('/slow'), importsDir.path);
    final errors = <String>[];
    final sub = service.errors.listen(errors.add);

    // Cancel only once the download is demonstrably mid-stream.
    await service.progress
        .firstWhere((value) => value > 0)
        .timeout(const Duration(seconds: 10));
    service.cancel();

    final result = await future;
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(result, isNull);
    expect(errors, contains('Download cancelled'));
    expect(
      importsDir.listSync(),
      isEmpty,
      reason: 'cancel must not leave a partial file or import folder',
    );
  });
}

String _parentName(String path) {
  final parts = path.replaceAll('\\', '/').split('/');
  return parts[parts.length - 2];
}
