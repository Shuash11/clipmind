import 'dart:io';

import 'package:dio/dio.dart';

/// Decides whether a finished download holds a media payload rather than
/// a web page — the failure mode where an HTML login/preview/error page
/// is saved under a `.mp4` name and silently imported as "video".
///
/// Two independent signals: the response Content-Type must not be
/// `text/html`, and the first bytes must not read as markup (`<…`).
class MediaPayloadInspector {
  const MediaPayloadInspector();

  /// Enough bytes for a BOM/whitespace-prefixed doctype while staying
  /// cheap to read for multi-gigabyte files.
  static const _sniffByteCount = 512;

  /// True when [headers] and [file]'s head look like media.
  Future<bool> isLikelyMedia(File file, {required Headers headers}) async {
    final contentType =
        headers.value(Headers.contentTypeHeader)?.trim().toLowerCase() ?? '';
    if (contentType.startsWith('text/html')) return false;
    return !await _startsAsMarkup(file);
  }

  Future<bool> _startsAsMarkup(File file) async {
    final head = await _readHead(file);
    if (head.isEmpty) return false;
    // `trimLeft` skips leading whitespace (and a UTF-8 BOM), so documents
    // that open with a newline before `<!DOCTYPE html>` are still caught.
    return String.fromCharCodes(head).trimLeft().startsWith('<');
  }

  Future<List<int>> _readHead(File file) async {
    final handle = await file.open();
    try {
      return await handle.read(_sniffByteCount);
    } finally {
      await handle.close();
    }
  }
}
