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
  String outputPath,
) async {
  final future = service.import(url, outputPath);
  final errors = <String>[];
  final sub = service.errors.listen(errors.add);
  final result = await future;
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return (result: result, errors: errors);
}

void _stubDownloadSuccess(_MockDio dio, List<int> bytes) {
  when(
    () => dio.download(
      any<String>(),
      any<String>(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((invocation) async {
    final savePath = invocation.positionalArguments[1] as String;
    await File(savePath).writeAsBytes(bytes, flush: true);
    return Response(
      requestOptions: RequestOptions(path: savePath),
      statusCode: 200,
    );
  });
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

  String out(String name) => '${tempDir.path}/$name.mp4';

  group('drive link handling', () {
    test('drive file/d URL is rejected with the guidance message', () async {
      final dio = _MockDio();
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
        out('drive_file'),
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
        out('drive_docs'),
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
        out('drive_uc'),
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
        out('bare_id'),
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
        final outcome = await _runImport(service, url, out('empty'));
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
        out('scheme_file'),
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
        out('scheme_ftp'),
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
        out('scheme_data'),
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
      final outcome = await _runImport(
        service,
        'not a url',
        out('unparseable'),
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals(['Only http and https download links are supported.']),
      );
      _verifyNoDownload(dio);
    });
  });

  group('direct download', () {
    test('happy path writes the file and returns its path', () async {
      final dio = _MockDio();
      _stubDownloadSuccess(dio, [1, 2, 3, 4]);
      final service = UrlImportService(dio: dio);
      final destination = out('direct_ok');
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        destination,
      );
      expect(outcome.result, equals(destination));
      expect(outcome.errors, isEmpty);
      expect(await File(destination).readAsBytes(), equals([1, 2, 3, 4]));
    });
  });

  group('cancellation mapping', () {
    test('Dio cancel maps to Download cancelled', () async {
      final dio = _MockDio();
      when(
        () => dio.download(
          any<String>(),
          any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.cancel,
        ),
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        out('dio_cancel'),
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals(['Download cancelled']));
    });

    test('non-cancel Dio errors keep their raw text', () async {
      final dio = _MockDio();
      when(
        () => dio.download(
          any<String>(),
          any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final service = UrlImportService(dio: dio);
      final outcome = await _runImport(
        service,
        'https://example.com/video.mp4',
        out('dio_timeout'),
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, hasLength(1));
      expect(outcome.errors.single, isNot(contains('Download cancelled')));
    });
  });
}
