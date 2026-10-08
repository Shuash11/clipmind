import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'import_filename.dart';
import 'media_payload_inspector.dart';

class GDriveInvalidInputException implements Exception {
  final String message;

  const GDriveInvalidInputException(this.message);

  @override
  String toString() => message;
}

/// Downloads a video from a direct http/https link into a local file.
///
/// Every import lands in its own `{targetDir}/<uuid>` folder under a
/// filename derived from the server (Content-Disposition) or the URL, so
/// two imports can never overwrite each other and the written basename is
/// the real media name. Google Drive share links are rejected with
/// [driveLinkMessage]; links that serve a web page are rejected with
/// [notVideoMessage]. Failures leave no partial file or folder behind.
class UrlImportService {
  static const driveLinkMessage =
      "Google Drive share links can't be downloaded directly. "
      'Download the file from Drive, then drag it into ClipMind.';

  /// Typed guidance for links that serve a web page (login walls,
  /// preview pages, error documents) instead of a video file. Surfaced on
  /// [errors] so the consumer can show it verbatim.
  static const notVideoMessage =
      'The link returned a web page instead of a video file. '
      'Use a direct video download link.';

  final Dio _dio;
  final ImportFilename _filenameResolver = const ImportFilename();
  final MediaPayloadInspector _payloadInspector = const MediaPayloadInspector();
  final Uuid _uuid = const Uuid();

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

  /// Downloads [fileUrl] into a fresh subfolder of [targetDir] and returns
  /// the absolute path of the written file, or `null` on failure.
  ///
  /// Lifecycle mirrors the previous contract: progress lands on [progress],
  /// failures on [errors] (with [cancel] mapping to `Download cancelled`),
  /// and the returned path is what the consumer turns into a project.
  Future<String?> import(String fileUrl, String targetDir) async {
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
      return await _downloadDirect(trimmedUrl, targetDir);
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

  Future<String?> _downloadDirect(String fileUrl, String targetDir) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
      throw const GDriveInvalidInputException(
        'Only http and https download links are supported.',
      );
    }

    // Unique per-import folder: two imports can never collide on a name,
    // and a failed attempt can be removed as one unit.
    final importDir = Directory('$targetDir/${_uuid.v4()}');
    await importDir.create(recursive: true);

    try {
      var outputPath = '${importDir.path}/video.mp4';
      // Dio invokes this with the response headers before creating the
      // file, so the real filename is known before a single byte lands.
      FutureOr<String> savePath(Headers headers) {
        final name = _filenameResolver.resolve(
          headers: headers,
          requestUri: uri,
        );
        outputPath = '${importDir.path}/$name';
        return outputPath;
      }

      final response = await _dio.download(
        fileUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) _progress?.add(received / total);
        },
      );

      final written = File(outputPath);
      if (!written.existsSync() || written.lengthSync() == 0) {
        await _removeImportDir(importDir);
        _reportError('Downloaded file is empty: $outputPath');
        return null;
      }
      final looksLikeMedia = await _payloadInspector.isLikelyMedia(
        written,
        headers: response.headers,
      );
      if (!looksLikeMedia) {
        await _removeImportDir(importDir);
        _reportError(notVideoMessage);
        return null;
      }
      return outputPath;
    } on Object {
      // Transport/cancel failure: dio's deleteOnError removes the partial
      // file; remove the per-import folder as well so nothing partial
      // survives a failed attempt.
      await _removeImportDir(importDir);
      rethrow;
    }
  }

  /// Deletes the per-import folder, never throwing — cleanup must not mask
  /// the import outcome. Retries briefly because on Windows the recursive
  /// delete can race dio's own cancel cleanup, which still holds the
  /// partial file open for a few milliseconds.
  Future<void> _removeImportDir(Directory dir) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        if (!await dir.exists()) return;
        await dir.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      } catch (_) {
        return;
      }
    }
  }

  void cancel() {
    try {
      _cancelToken?.cancel('Cancelled by user');
    } catch (_) {}
  }
}
