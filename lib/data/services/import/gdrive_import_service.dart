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

class GDriveImportService {
  static const driveApiUnsupportedMessage =
      'Google Drive import is not available on Windows. '
      'Google Sign-In has no Windows implementation, so Drive API '
      'downloads cannot start on this platform. '
      'Use a direct video link, YouTube, or a local file instead.';

  static bool get isDriveApiSupported => !Platform.isWindows;

  final Dio _dio;
  CancelToken? _cancelToken;
  GoogleAuthClient? _activeClient;
  bool _cancelRequested = false;
  StreamController<double>? _progress;
  StreamController<String>? _errorStream;

  Stream<double> get progress => _progress?.stream ?? const Stream.empty();
  Stream<String> get errors => _errorStream?.stream ?? const Stream.empty();

  GDriveImportService() : _dio = Dio();

  String? _extractFileId(String url) {
    final patterns = [
      RegExp(r'/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'id=([a-zA-Z0-9_-]+)'),
      RegExp(r'^([a-zA-Z0-9_-]{25,})$'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  Future<String?> import(String fileUrl, String outputPath) async {
    _progress = StreamController<double>.broadcast();
    _errorStream = StreamController<String>.broadcast();
    _cancelRequested = false;
    _cancelToken = CancelToken();
    _activeClient = null;

    try {
      final fileId = _extractFileId(fileUrl);
      if (fileId == null) {
        return await _downloadDirect(fileUrl, outputPath);
      }
      if (!isDriveApiSupported) {
        _errorStream?.add(driveApiUnsupportedMessage);
        return null;
      }
      return await _downloadViaApi(fileId, outputPath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _errorStream?.add('Download cancelled');
      } else {
        _errorStream?.add(e.toString());
      }
      return null;
    } on GDriveUnsupportedPlatformException catch (e) {
      _errorStream?.add(e.message);
      return null;
    } catch (e) {
      _errorStream?.add(e.toString());
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
    await _dio.download(
      fileUrl,
      outputPath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) _progress?.add(received / total);
      },
    );
    return outputPath;
  }

  Future<String?> _downloadViaApi(String fileId, String outputPath) async {
    if (!isDriveApiSupported) {
      throw const GDriveUnsupportedPlatformException();
    }
    final googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveReadonlyScope],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      _errorStream?.add('Google Sign-In cancelled');
      return null;
    }

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _activeClient = client;
    final driveApi = drive.DriveApi(client);

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
