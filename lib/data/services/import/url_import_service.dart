import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

class GDriveInvalidInputException implements Exception {
  final String message;

  const GDriveInvalidInputException(this.message);

  @override
  String toString() => message;
}

/// Downloads a video from a direct http/https link into a local file.
///
/// Google Drive share links are rejected with [driveLinkMessage]: Drive
/// files need interactive download via the Drive website, which this
/// desktop importer cannot perform without a Google OAuth client.
class UrlImportService {
  static const driveLinkMessage =
      "Google Drive share links can't be downloaded directly. "
      'Download the file from Drive, then drag it into ClipMind.';

  final Dio _dio;

  CancelToken? _cancelToken;
  StreamController<double>? _progress;
  StreamController<String>? _errorStream;

  Stream<double> get progress => _progress?.stream ?? const Stream.empty();
  Stream<String> get errors => _errorStream?.stream ?? const Stream.empty();

  /// Test seam: inject a fake Dio. Defaults to a real Dio.
  UrlImportService({Dio? dio}) : _dio = dio ?? Dio();

  /// Reports an import failure on [errors].
  ///
  /// Emissions raised synchronously (empty input, Drive link, bad URL
  /// scheme) are deferred to a microtask: broadcast controllers drop
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

  Future<String?> import(String fileUrl, String outputPath) async {
    _progress = StreamController<double>.broadcast();
    _errorStream = StreamController<String>.broadcast();
    _cancelToken = CancelToken();

    try {
      final trimmedUrl = fileUrl.trim();
      if (trimmedUrl.isEmpty) {
        throw const GDriveInvalidInputException('Import URL is empty');
      }
      final host = Uri.tryParse(trimmedUrl)?.host.toLowerCase();
      if (host == 'drive.google.com' || host == 'docs.google.com') {
        throw const GDriveInvalidInputException(driveLinkMessage);
      }
      return await _downloadDirect(trimmedUrl, outputPath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _reportError('Download cancelled');
      } else {
        _reportError(e.toString());
      }
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

  void cancel() {
    try {
      _cancelToken?.cancel('Cancelled by user');
    } catch (_) {}
  }
}
