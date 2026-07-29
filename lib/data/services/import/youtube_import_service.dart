import 'dart:async';
import 'dart:convert';
import 'dart:io';

class YouTubeImportService {
  StreamController<double>? _progress;
  StreamController<String>? _errorStream;
  Process? _process;

  Stream<double> get progress => _progress?.stream ?? const Stream.empty();
  Stream<String> get errors => _errorStream?.stream ?? const Stream.empty();

  Future<String?> import(String url, String outputDir) async {
    _progress = StreamController<double>.broadcast();
    _errorStream = StreamController<String>.broadcast();

    try {
      _process = await Process.start('yt-dlp', [
        '--newline',
        '--no-warnings',
        '--print',
        'after_move:filepath',
        '-o',
        '$outputDir/%(title)s.%(ext)s',
        '--no-playlist',
        url,
      ]);

      if (_process == null) return null;

      String? downloadedFile;

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && !trimmed.startsWith('[')) {
              downloadedFile = trimmed;
            }
          });

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains('ERROR:')) {
              _errorStream?.add(line);
            }
            final percentMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(line);
            if (percentMatch != null) {
              final pct = double.tryParse(percentMatch.group(1)!);
              if (pct != null) _progress?.add(pct / 100.0);
            }
          });

      final exitCode = await _process!.exitCode;
      if (exitCode == 0 && downloadedFile != null) {
        _progress?.add(1.0);
        return downloadedFile;
      }
      return null;
    } catch (e) {
      _errorStream?.add(e.toString());
      return null;
    } finally {
      await _progress?.close();
      _progress = null;
      await _errorStream?.close();
      _errorStream = null;
      _process = null;
    }
  }

  void cancel() {
    _process?.kill();
  }
}
