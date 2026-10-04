// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleAuthClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Map<String, String> _headers;

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class GDriveUnsupportedPlatformException implements Exception {
  final String message;

  const GDriveUnsupportedPlatformException([
    this.message = GDriveImportService.driveApiUnsupportedMessage,
  ]);

  @override
  String toString() => message;
}

class GDriveInvalidInputException implements Exception {
  final String message;

  const GDriveInvalidInputException(this.message);

  @override
  String toString() => message;
}

class GDriveImportService {
  static const driveApiUnsupportedMessage =
      'Google Drive import is not available on Windows. '
      'Google Sign-In has no Windows implementation, so Drive API '
      'downloads cannot start on this platform. '
      'Use a direct video link, YouTube, or a local file instead.';

  static bool get isDriveApiSupported => !Platform.isWindows;

  final Dio _dio;

  /// Test seam: replaces the platform gate so tests can force the
  /// supported/unsupported paths deterministically on any host OS.
  /// Defaults to the real [isDriveApiSupported] gate.
  final bool Function() _driveApiSupported;

  /// Test seam: replaces the Google sign-in call so tests never construct
  /// a real [GoogleSignIn]. Defaults to [_defaultSignIn].
  final Future<GoogleSignInAccount?> Function()? _signIn;

  /// Test seam: replaces Drive API construction so tests can inject a fake.
  /// Defaults to the real [drive.DriveApi].
  final drive.DriveApi Function(http.Client client)? _driveApiFactory;

  CancelToken? _cancelToken;
  GoogleAuthClient? _activeClient;
  bool _cancelRequested = false;
  StreamController<double>? _progress;
  StreamController<String>? _errorStream;

  Stream<double> get progress => _progress?.stream ?? const Stream.empty();
  Stream<String> get errors => _errorStream?.stream ?? const Stream.empty();

  GDriveImportService({
    Dio? dio,
    bool Function()? driveApiSupported,
    Future<GoogleSignInAccount?> Function()? signIn,
    drive.DriveApi Function(http.Client client)? driveApiFactory,
  })  : _dio = dio ?? Dio(),
        _driveApiSupported = driveApiSupported ?? (() => !Platform.isWindows),
        _signIn = signIn,
        _driveApiFactory = driveApiFactory;

  Future<GoogleSignInAccount?> _defaultSignIn() {
    final googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveReadonlyScope],
    );
    return googleSignIn.signIn();
  }

  /// Reports an import failure on [errors].
  ///
  /// Emissions raised synchronously (empty input, unsupported platform, bad
  /// URL scheme) are deferred to a microtask: broadcast controllers drop
  /// events added while nobody is listening, so a listener subscribing
  /// right after [import] is called would otherwise miss them.
  void _reportError(String message) {
    final errors = _errorStream;
    if (errors == null || errors.isClosed) return;
    if (errors.hasListener) {
      errors.add(message);
    } else {
      scheduleMicrotask(() {
        if (errors.isClosed) return;
        errors.add(message);
      });
    }
  }

  String? _extractFileId(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase();
    final isDriveHost =
        host == 'drive.google.com' || host == 'docs.google.com';
    if (isDriveHost) {
      final fileMatch =
          RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
      if (fileMatch != null) return fileMatch.group(1);
      final idMatch = RegExp(r'id=([a-zA-Z0-9_-]+)').firstMatch(url);
      if (idMatch != null) return idMatch.group(1);
    }
    final bareMatch = RegExp(r'^([a-zA-Z0-9_-]{25,})$').firstMatch(url);
    if (bareMatch != null) return bareMatch.group(1);
    return null;
  }

  Future<String?> import(String fileUrl, String outputPath) async {
    _progress = StreamController<double>.broadcast();
    _errorStream = StreamController<String>.broadcast();
    _cancelRequested = false;
    _cancelToken = CancelToken();
    _activeClient = null;

    try {
      final trimmedUrl = fileUrl.trim();
      if (trimmedUrl.isEmpty) {
        throw const GDriveInvalidInputException('Import URL is empty');
      }
      final fileId = _extractFileId(trimmedUrl);
      if (fileId == null) {
        return await _downloadDirect(trimmedUrl, outputPath);
      }
      if (!_driveApiSupported()) {
        _reportError(driveApiUnsupportedMessage);
        return null;
      }
      return await _downloadViaApi(fileId, outputPath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _reportError('Download cancelled');
      } else {
        _reportError(e.toString());
      }
      return null;
    } on GDriveUnsupportedPlatformException catch (e) {
      _reportError(e.message);
      return null;
    } on GDriveInvalidInputException catch (e) {
      _reportError(e.message);
      return null;
    } catch (e) {
      _reportError(e.toString());
      return null;
    } finally {
      await _progress?.close();
      _progress = null;
      await _errorStream?.close();
      _errorStream = null;
      _cancelToken = null;
      _activeClient = null;
    }
  }

  Future<String?> _downloadDirect(String fileUrl, String outputPath) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
      throw const GDriveInvalidInputException(
        'Only http and https download links are supported.',
      );
    }
    await _dio.download(
      fileUrl,
      outputPath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) _progress?.add(received / total);
      },
    );
    final written = File(outputPath);
    if (!written.existsSync() || written.lengthSync() == 0) {
      throw Exception('Downloaded file is empty: $outputPath');
    }
    return outputPath;
  }

  Future<String?> _downloadViaApi(String fileId, String outputPath) async {
    if (!_driveApiSupported()) {
      throw const GDriveUnsupportedPlatformException();
    }
    final account = await (_signIn?.call() ?? _defaultSignIn());
    if (account == null) {
      _reportError('Google Sign-In cancelled');
      return null;
    }

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _activeClient = client;
    final driveApi = _driveApiFactory?.call(client) ?? drive.DriveApi(client);

    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    try {
      if (_cancelRequested || (_cancelToken?.isCancelled ?? false)) {
        throw DioException(
          requestOptions: RequestOptions(path: outputPath),
          type: DioExceptionType.cancel,
        );
      }
      if (response is drive.Media) {
        final file = File(outputPath);
        final sink = file.openWrite();
        try {
          int totalDownloaded = 0;
          final totalBytes = response.length ?? -1;

          await for (final chunk in response.stream) {
            if (_cancelRequested || (_cancelToken?.isCancelled ?? false)) {
              throw DioException(
                requestOptions: RequestOptions(path: outputPath),
                type: DioExceptionType.cancel,
              );
            }
            sink.add(chunk);
            totalDownloaded += chunk.length;
            if (totalBytes > 0) {
              _progress?.add(totalDownloaded / totalBytes);
            }
          }
          await sink.flush();
          await sink.close();
        } catch (_) {
          try {
            await sink.close();
          } catch (_) {}
          rethrow;
        }
      }
      return outputPath;
    } finally {
      client.close();
      if (identical(_activeClient, client)) _activeClient = null;
    }
  }

  void cancel() {
    _cancelRequested = true;
    try {
      _cancelToken?.cancel('Cancelled by user');
    } catch (_) {}
    try {
      _activeClient?.close();
    } catch (_) {}
  }
}
