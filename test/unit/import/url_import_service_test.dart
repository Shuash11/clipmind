import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/data/services/import/url_import_service.dart';

class _MockDio extends Mock implements Dio {}

void _noopProgress(int received, int total) {}

/// Runs [service.import] and captures the result plus every [errors] event.
///
/// The subscription is attached synchronously right after [import] is
/// invoked so fail-fast errors (raised before the first await) are still
/// observed; a trailing pump flushes deferred emissions before returning.
Future<({String? result, List<String> errors})> _runImport(
  UrlImportService service,
  String url,
  String targetDir,
) async {
  final future = service.import(url, targetDir);
  final errors = <String>[];
  final sub = service.errors.listen(errors.add);
  final result = await future;
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return (result: result, errors: errors);
}

Headers _headers({String? disposition, String? contentType}) {
  final map = <String, List<String>>{};
  if (disposition != null) map['content-disposition'] = [disposition];
  if (contentType != null) map['content-type'] = [contentType];
  return Headers.fromMap(map);
}

/// Stubs `dio.download` to mirror the real contract: the `savePath`
/// function is invoked with the response headers (which decide the
/// filename), the body is written to the returned path, and the response
/// carries the same headers. Payloads are consumed in order, one per call.
void _stubDownload(
  _MockDio dio,
  List<List<int>> payloads, {
  List<Headers>? headersPerCall,
}) {
  var call = 0;
  when(
    () => dio.download(
      any<String>(),
      any<String>(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((invocation) async {
    final index = call < payloads.length ? call : payloads.length - 1;
    call++;
    final headers = headersPerCall != null && index < headersPerCall.length
        ? headersPerCall[index]
        : Headers();
    final savePath = invocation.positionalArguments[1]
        as FutureOr<String> Function(Headers);
    final path = await savePath(headers);
    await File(path).create(recursive: true);
    await File(path).writeAsBytes(payloads[index], flush: true);
    return Response(
      requestOptions: RequestOptions(path: 'https://example.com/video.mp4'),
      statusCode: 200,
      headers: headers,
    );
  });
}

void _stubDioFailure(_MockDio dio, DioException error) {
  when(
    () => dio.download(
      any<String>(),
      any<String>(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenThrow(error);
}

void _verifyNoDownload(_MockDio dio) {
  verifyNever(
    () => dio.download(
      any<String>(),
      any<String>(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  );
}

String _basename(String path) => path.replaceAll('\\', '/').split('/').last;

String _parentName(String path) {
  final parts = path.replaceAll('\\', '/').split('/');
  return parts[parts.length - 2];
}

final _uuidFolder = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Asserts the import landed at `{targetDir}/<uuid>/[expectedName]`.
void _expectStoredAs(String? path, String targetDir, String expectedName) {
  expect(path, isNotNull);
  final normalized = path!.replaceAll('\\', '/');
  final normalizedDir = targetDir.replaceAll('\\', '/');
  expect(normalized, startsWith('$normalizedDir/'));
  expect(_basename(normalized), expectedName);
  expect(
    _uuidFolder.hasMatch(_parentName(normalized)),
    isTrue,
    reason: 'expected a uuid-named per-import folder: $path',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue(_noopProgress);
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('url_import_test_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('drive link handling', () {
    test('drive file/d URL is rejected with the guidance message', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([UrlImportService.driveLinkMessage]));
      _verifyNoDownload(dio);
    });

    test('docs.google.com URL is rejected with the guidance message',
        () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://docs.google.com/uc?id=ABCdef1234567890ABCdef12&export=download',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([UrlImportService.driveLinkMessage]));
      _verifyNoDownload(dio);
    });

    test('drive uc?id= URL is rejected with the guidance message', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://drive.google.com/uc?id=ABCdef1234567890ABCdef12&export=download',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([UrlImportService.driveLinkMessage]));
      _verifyNoDownload(dio);
    });

    test('bare 25+ char ID falls through to scheme validation', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'ABCDefghij1234567890abcdef12',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals(['Only http and https download links are supported.']),
      );
      _verifyNoDownload(dio);
    });
  });

  group('input validation', () {
    test('empty and whitespace URLs are rejected without a Dio call',
        () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      for (final url in ['', '   ']) {
        final outcome = await _runImport(service, url, tempDir.path);
        expect(outcome.result, isNull);
        expect(outcome.errors, equals(['Import URL is empty']));
      }
      _verifyNoDownload(dio);
    });

    test('file: scheme is rejected', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'file:///C:/videos/x.mp4',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals(['Only http and https download links are supported.']),
      );
      _verifyNoDownload(dio);
    });

    test('ftp: scheme is rejected', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'ftp://host/x.mp4',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals(['Only http and https download links are supported.']),
      );
      _verifyNoDownload(dio);
    });

    test('data: URI is rejected', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'data:text/plain;base64,aGk=',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals(['Only http and https download links are supported.']),
      );
      _verifyNoDownload(dio);
    });

    test('unparseable URL is rejected', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(service, 'not a url', tempDir.path);
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals(['Only http and https download links are supported.']),
      );
      _verifyNoDownload(dio);
    });
  });

  group('download storage', () {
    test('happy path stores the file in a uuid folder and returns its path',
        () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        [1, 2, 3, 4],
      ]);
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        tempDir.path,
      );
      _expectStoredAs(outcome.result, tempDir.path, 'video.mp4');
      expect(outcome.errors, isEmpty);
      expect(await File(outcome.result!).readAsBytes(), equals([1, 2, 3, 4]));
    });

    test('two consecutive imports get distinct files and both stay intact',
        () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        [1, 2, 3],
        [9, 8, 7],
      ]);
      final service = UrlImportService(dio: dio);

      final first = await _runImport(
        service,
        'https://example.com/first.mp4',
        tempDir.path,
      );
      final second = await _runImport(
        service,
        'https://example.com/second.mp4',
        tempDir.path,
      );

      _expectStoredAs(first.result, tempDir.path, 'first.mp4');
      _expectStoredAs(second.result, tempDir.path, 'second.mp4');
      expect(first.result, isNot(equals(second.result)));
      expect(
        await File(first.result!).readAsBytes(),
        equals([1, 2, 3]),
        reason: 'the second import must never overwrite the first',
      );
      expect(await File(second.result!).readAsBytes(), equals([9, 8, 7]));
    });

    test('URL basename is the fallback filename', () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        [1],
      ]);
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/media/clip.mp4',
        tempDir.path,
      );
      _expectStoredAs(outcome.result, tempDir.path, 'clip.mp4');
    });

    test('percent-encoded URL segment is decoded', () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        [1],
      ]);
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/caf%C3%A9%20clip.mp4',
        tempDir.path,
      );
      _expectStoredAs(outcome.result, tempDir.path, 'café clip.mp4');
    });

    test('nameless URL falls back to video.mp4', () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        [1],
      ]);
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/',
        tempDir.path,
      );
      _expectStoredAs(outcome.result, tempDir.path, 'video.mp4');
    });
  });

  group('filename derivation', () {
    Future<String?> nameFor(
      String url, {
      String? disposition,
      String? contentType,
      Headers? headers,
    }) async {
      final dio = _MockDio();
      _stubDownload(
        dio,
        [
          [1],
        ],
        headersPerCall: [
          headers ?? _headers(disposition: disposition, contentType: contentType),
        ],
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(service, url, tempDir.path);
      expect(outcome.errors, isEmpty);
      return outcome.result == null ? null : _basename(outcome.result!);
    }

    test('filename* (RFC 5987) wins and is percent-decoded', () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: "attachment; filename*=UTF-8''caf%C3%A9%20clip.mp4",
      );
      expect(name, 'café clip.mp4');
    });

    test('quoted filename is used and keeps its own extension', () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: 'attachment; filename="my video (final).webm"',
        contentType: 'video/mp4',
      );
      expect(name, 'my video (final).webm');
    });

    test('unquoted filename is used', () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: 'attachment; filename=plain-clip.mp4',
      );
      expect(name, 'plain-clip.mp4');
    });

    test('filename* wins over filename and the URL', () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition:
            "attachment; filename=\"old.mp4\"; filename*=UTF-8''new%20name.mp4",
      );
      expect(name, 'new name.mp4');
    });

    test('missing extension takes the Content-Type mapping', () async {
      final name = await nameFor(
        'https://example.com/stream',
        contentType: 'video/webm',
      );
      expect(name, 'stream.webm');
    });

    test('missing extension with unknown Content-Type defaults to .mp4',
        () async {
      final name = await nameFor(
        'https://example.com/stream',
        contentType: 'application/octet-stream',
      );
      expect(name, 'stream.mp4');
    });

    test('traversal in the filename is neutralized', () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: 'attachment; filename="../../evil.mp4"',
      );
      expect(name, '____evil.mp4');
      expect(name, isNot(contains('..')));
      expect(name, isNot(contains('/')));
    });

    test('path separators in the filename cannot escape the folder',
        () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: r'attachment; filename="sub/dir\clip.mp4"',
      );
      expect(name, 'sub_dir_clip.mp4');
    });

    test('reserved device names are renamed', () async {
      expect(
        await nameFor(
          'https://example.com/url-name.mp4',
          disposition: 'attachment; filename="CON.mp4"',
        ),
        'CON_import.mp4',
      );
      expect(
        await nameFor(
          'https://example.com/url-name.mp4',
          disposition: 'attachment; filename="lpt1.webm"',
        ),
        'lpt1_import.webm',
      );
    });

    test('control characters and quoted-string artifacts are stripped',
        () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: 'attachment; filename="clip\nwith\x01bad.mp4"',
      );
      expect(name, 'clipwithbad.mp4');
    });

    test('a long stem is capped at 100 characters', () async {
      final name = await nameFor(
        'https://example.com/url-name.mp4',
        disposition: 'attachment; filename="${'a' * 150}.mp4"',
      );
      expect(name, '${'a' * 100}.mp4');
    });
  });

  group('payload validation', () {
    test('text/html Content-Type is rejected with no file left behind',
        () async {
      final dio = _MockDio();
      _stubDownload(
        dio,
        [
          utf8.encode('<!DOCTYPE html><html><body>login</body></html>'),
        ],
        headersPerCall: [_headers(contentType: 'text/html; charset=utf-8')],
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/page',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([UrlImportService.notVideoMessage]));
      expect(tempDir.listSync(), isEmpty);
    });

    test('markup body without an HTML Content-Type is rejected', () async {
      final dio = _MockDio();
      _stubDownload(
        dio,
        [
          utf8.encode('  <!DOCTYPE html><html>error</html>'),
        ],
        headersPerCall: [_headers(contentType: 'application/octet-stream')],
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/page',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([UrlImportService.notVideoMessage]));
      expect(tempDir.listSync(), isEmpty);
    });

    test('markup body with no Content-Type at all is rejected', () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        utf8.encode('<html><body>oops</body></html>'),
      ]);
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/page',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([UrlImportService.notVideoMessage]));
      expect(tempDir.listSync(), isEmpty);
    });

    test('empty download is rejected and leaves nothing behind', () async {
      final dio = _MockDio();
      _stubDownload(dio, [
        <int>[],
      ]);
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, hasLength(1));
      expect(outcome.errors.single, contains('empty'));
      expect(tempDir.listSync(), isEmpty);
    });
  });

  group('cancellation mapping', () {
    test('Dio cancel maps to Download cancelled and cleans up', () async {
      final dio = _MockDio();
      _stubDioFailure(
        dio,
        DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.cancel,
        ),
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals(['Download cancelled']));
      expect(tempDir.listSync(), isEmpty);
    });

    test('non-cancel Dio errors keep their raw text and clean up', () async {
      final dio = _MockDio();
      _stubDioFailure(
        dio,
        DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        tempDir.path,
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, hasLength(1));
      expect(outcome.errors.single, isNot(contains('Download cancelled')));
      expect(tempDir.listSync(), isEmpty);
    });
  });
}
