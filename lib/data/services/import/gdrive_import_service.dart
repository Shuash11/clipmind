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

class GDriveImportService {
  final Dio _dio;
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

    try {
      final fileId = _extractFileId(fileUrl);
      if (fileId == null) {
        return _downloadDirect(fileUrl, outputPath);
      }
      return _downloadViaApi(fileId, outputPath);
    } catch (e) {
      _errorStream?.add(e.toString());
      return null;
    } finally {
      await _progress?.close();
      _progress = null;
      await _errorStream?.close();
      _errorStream = null;
    }
  }

  Future<String?> _downloadDirect(String fileUrl, String outputPath) async {
    await _dio.download(
      fileUrl,
      outputPath,
      onReceiveProgress: (received, total) {
        if (total > 0) _progress?.add(received / total);
      },
    );
    return outputPath;
  }

  Future<String?> _downloadViaApi(String fileId, String outputPath) async {
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
    final driveApi = drive.DriveApi(client);

    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (response is drive.Media) {
      final file = File(outputPath);
      final sink = file.openWrite();
      int totalDownloaded = 0;
      final totalBytes = response.length ?? -1;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        totalDownloaded += chunk.length;
        if (totalBytes > 0) {
          _progress?.add(totalDownloaded / totalBytes);
        }
      }
      await sink.flush();
      await sink.close();
    }

    client.close();
    return outputPath;
  }

  void cancel() {
    // Dio doesn't support per-request cancellation without CancelToken
  }
}
