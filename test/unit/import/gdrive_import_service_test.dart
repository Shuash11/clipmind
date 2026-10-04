import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/data/services/import/gdrive_import_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockAccount extends Mock implements GoogleSignInAccount {}

class _FakeDriveApi extends Mock implements drive.DriveApi {}

class _FakeFilesResource extends Mock implements drive.FilesResource {}

void _noopProgress(int received, int total) {}

/// Runs [service.import] and captures the result plus every [errors] event.
///
/// The subscription is attached synchronously right after [import] is
/// invoked so fail-fast errors (raised before the first await) are still
/// observed; a trailing pump flushes deferred emissions before returning.
Future<({String? result, List<String> errors})> _runImport(
  GDriveImportService service,
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
    () => dio.download(any<String>(), any<String>(),
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

void main() {
  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(CancelToken());
    registerFallbackValue(_noopProgress);
    registerFallbackValue(drive.DownloadOptions.metadata);
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gdrive_test_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  String out(String name) => '${tempDir.path}/$name.mp4';

  group('platform gate (unsupported)', () {
    test('drive file/d URL fails fast with the honest message', () async {
      final dio = _MockDio();
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => false,
      );
      final outcome = await _runImport(
        service,
        'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
        out('gate_file'),
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals([GDriveImportService.driveApiUnsupportedMessage]),
      );
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('bare 25+ char ID fails fast with the honest message', () async {
      final dio = _MockDio();
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => false,
      );
      final outcome = await _runImport(
        service,
        'ABCDefghij1234567890abcdef12',
        out('gate_bare'),
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals([GDriveImportService.driveApiUnsupportedMessage]),
      );
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('drive uc?id= URL fails fast with the honest message', () async {
      final dio = _MockDio();
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => false,
      );
      final outcome = await _runImport(
        service,
        'https://drive.google.com/uc?id=ABCdef1234567890ABCdef12&export=download',
        out('gate_uc'),
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals([GDriveImportService.driveApiUnsupportedMessage]),
      );
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });
  });

  group('fileId host gating', () {
    test('non-Drive id= URL routes to direct download', () async {
      const url =
          'https://example.com/video?id=ABCDefghij1234567890abcdef12';
      final dio = _MockDio();
      _stubDownloadSuccess(dio, [1, 2, 3, 4]);
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => false,
      );
      final destination = out('host_id');
      final outcome = await _runImport(service, url, destination);
      expect(outcome.result, equals(destination));
      expect(outcome.errors, isEmpty);
      final captured =
          verify(
            () => dio.download(captureAny(), any<String>(),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            ),
          ).captured;
      expect(captured, equals([url]));
    });

    test('non-Drive file/d URL routes to direct download', () async {
      const url = 'https://example.com/file/d/ABCDefghij1234567890abcdef';
      final dio = _MockDio();
      _stubDownloadSuccess(dio, [5, 6, 7]);
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => false,
      );
      final destination = out('host_filed');
      final outcome = await _runImport(service, url, destination);
      expect(outcome.result, equals(destination));
      expect(outcome.errors, isEmpty);
      final captured =
          verify(
            () => dio.download(captureAny(), any<String>(),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            ),
          ).captured;
      expect(captured, equals([url]));
    });
  });

  group('input validation', () {
    test('empty and whitespace URLs are rejected without a Dio call',
        () async {
      final dio = _MockDio();
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => true,
      );
      for (final url in ['', '   ']) {
        final outcome = await _runImport(service, url, out('empty'));
        expect(outcome.result, isNull);
        expect(outcome.errors, equals(['Import URL is empty']));
      }
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('file: scheme is rejected', () async {
      final dio = _MockDio();
      final service = GDriveImportService(dio: dio);
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
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('ftp: scheme is rejected', () async {
      final dio = _MockDio();
      final service = GDriveImportService(dio: dio);
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
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('data: URI is rejected', () async {
      final dio = _MockDio();
      final service = GDriveImportService(dio: dio);
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
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('unparseable URL is rejected', () async {
      final dio = _MockDio();
      final service = GDriveImportService(dio: dio);
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
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });
  });

  group('direct download', () {
    test('happy path writes the file and returns its path', () async {
      final dio = _MockDio();
      _stubDownloadSuccess(dio, [1, 2, 3, 4]);
      final service = GDriveImportService(dio: dio);
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

  group('platform gate determinism', () {
    test('docs.google.com URL hits the gate on any host OS', () async {
      final dio = _MockDio();
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => false,
      );
      final outcome = await _runImport(
        service,
        'https://docs.google.com/uc?id=ABCdef1234567890ABCdef12&export=download',
        out('gate_docs'),
      );
      expect(outcome.result, isNull);
      expect(
        outcome.errors,
        equals([GDriveImportService.driveApiUnsupportedMessage]),
      );
      verifyNever(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('cancelled sign-in reports once and resolves the seam once',
        () async {
      var calls = 0;
      final dio = _MockDio();
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => true,
        signIn: () async {
          calls++;
          return null;
        },
      );
      final outcome = await _runImport(
        service,
        'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
        out('signin_cancelled'),
      );
      expect(outcome.result, isNull);
      expect(outcome.errors, equals(['Google Sign-In cancelled']));
      expect(calls, equals(1));
    });
  });

  group('cancellation mapping', () {
    test('Dio cancel maps to Download cancelled', () async {
      final dio = _MockDio();
      when(
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.cancel,
        ),
      );
      final service = GDriveImportService(dio: dio);
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
        () => dio.download(any<String>(), any<String>(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final service = GDriveImportService(dio: dio);
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

  group('Drive API path', () {
    test('cooperative cancel surfaces Download cancelled', () async {
      final dio = _MockDio();
      final account = _MockAccount();
      when(
        () => account.authHeaders,
      ).thenAnswer((_) async => {'Authorization': 'Bearer test'});
      final api = _FakeDriveApi();
      final files = _FakeFilesResource();
      when(() => api.files).thenReturn(files);
      final mediaController = StreamController<List<int>>();
      when(
        () => files.get(any<String>(),
          downloadOptions: any(named: 'downloadOptions'),
        ),
      ).thenAnswer((_) async => drive.Media(mediaController.stream, null));
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => true,
        signIn: () async => account,
        driveApiFactory: (_) => api,
      );
      final future = service.import(
        'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
        out('api_cancel'),
      );
      final errors = <String>[];
      final sub = service.errors.listen(errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      mediaController.add([1, 2, 3]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      service.cancel();
      mediaController.add([4, 5]);
      await mediaController.close();
      final result = await future;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(result, isNull);
      expect(errors, contains('Download cancelled'));
      // Cancelling a completed import must stay safe.
      service.cancel();
    });

    test('happy path writes exact bytes and reports full progress', () async {
      final dio = _MockDio();
      final account = _MockAccount();
      when(
        () => account.authHeaders,
      ).thenAnswer((_) async => {'Authorization': 'Bearer test'});
      final api = _FakeDriveApi();
      final files = _FakeFilesResource();
      when(() => api.files).thenReturn(files);
      const bytes = [10, 20, 30, 40, 50];
      when(
        () => files.get(any<String>(),
          downloadOptions: any(named: 'downloadOptions'),
        ),
      ).thenAnswer(
        (_) async => drive.Media(Stream<List<int>>.value(bytes), bytes.length),
      );
      final service = GDriveImportService(
        dio: dio,
        driveApiSupported: () => true,
        signIn: () async => account,
        driveApiFactory: (_) => api,
      );
      final destination = out('api_ok');
      final future = service.import(
        'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
        destination,
      );
      final errors = <String>[];
      final errorSub = service.errors.listen(errors.add);
      final progresses = <double>[];
      final progressSub = service.progress.listen(progresses.add);
      final result = await future;
      await Future<void>.delayed(Duration.zero);
      await errorSub.cancel();
      await progressSub.cancel();
      expect(result, equals(destination));
      expect(errors, isEmpty);
      expect(await File(destination).readAsBytes(), equals(bytes));
      expect(progresses, isNotEmpty);
      expect(progresses.last, equals(1.0));
    });
  });
}
