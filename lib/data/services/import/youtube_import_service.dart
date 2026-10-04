import 'dart:async';
import 'dart:convert';
import 'dart:io';

class YouTubeImportService {
  /// Typed missing-binary guidance, surfaced on [errors] when `yt-dlp`
  /// cannot be started. Same actionable-message family as the FFmpeg
  /// binary-not-found failures.
  static const missingBinaryMessage =
      'yt-dlp not found — install it (yt-dlp.exe or winget) '
      'or configure the path in settings';

  /// Stall watchdog window: a healthy yt-dlp emits stdout/stderr lines
  /// regularly, so firing only when no output arrives for [stallTimeout]
  /// means the child is truly hung. No total-duration cap.
  final Duration stallTimeout;

  /// Test seam, consistent with `runJob`/`runProbe`/`startProcess`: replaces
  /// the real `Process.start` so tests can inject controllable output lines,
  /// a never-completing exitCode, and a killed flag without spawning yt-dlp.
  final Future<Process> Function(String executable, List<String> args)?
      startProcess;

  /// Test seam for the Windows tree-kill command. When non-null, replaces
  /// the real `Process.run('taskkill', ...)` so tests can verify the
  /// tree-kill was issued without spawning processes.
  final Future<ProcessResult> Function(String executable, List<String> args)?
      runTreeKill;

  StreamController<double>? _progress;
  StreamController<String>? _errorStream;
  Process? _process;

  YouTubeImportService({
    this.stallTimeout = const Duration(seconds: 120),
    this.startProcess,
    this.runTreeKill,
  });

  Stream<double> get progress => _progress?.stream ?? const Stream.empty();
  Stream<String> get errors => _errorStream?.stream ?? const Stream.empty();

  /// Visible for testing: true while an import holds a child handle.
  bool get hasActiveProcess => _process != null;

  static String stallMessage(Duration timeout) =>
      'yt-dlp stalled — no output for ${timeout.inSeconds}s — '
      'the download took too long or the connection stalled';

  Future<String?> import(String url, String outputDir) async {
    _progress = StreamController<double>.broadcast();
    _errorStream = StreamController<String>.broadcast();

    Timer? watchdog;
    final stallSignal = Completer<void>();
    var stalled = false;
    var lastActivity = DateTime.now();
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;

    void markActivity() {
      lastActivity = DateTime.now();
    }

    try {
      final args = [
        '--newline',
        '--no-warnings',
        '--print',
        'after_move:filepath',
        '-o',
        '$outputDir/%(title)s.%(ext)s',
        '--no-playlist',
        url,
      ];
      final starter = startProcess;
      try {
        _process = starter != null
            ? await starter('yt-dlp', args)
            : await Process.start('yt-dlp', args);
      } on ProcessException {
        _errorStream?.add(missingBinaryMessage);
        return null;
      }

      final proc = _process;
      if (proc == null) return null;

      String? downloadedFile;

      stdoutSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        markActivity();
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('[')) {
          downloadedFile = trimmed;
        }
      });

      stderrSub = proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        markActivity();
        if (line.contains('ERROR:')) {
          _errorStream?.add(line);
        }
        final percentMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(line);
        if (percentMatch != null) {
          final pct = double.tryParse(percentMatch.group(1)!);
          if (pct != null) _progress?.add(pct / 100.0);
        }
      });

      // Stall watchdog: a periodic timer fires when no stdout/stderr line
      // has arrived for [stallTimeout]. Healthy downloads emit lines
      // continuously, so only a hung yt-dlp trips it.
      final tickMs = (stallTimeout.inMilliseconds ~/ 4).clamp(20, 1000);
      watchdog = Timer.periodic(Duration(milliseconds: tickMs), (_) {
        if (stalled) return;
        if (DateTime.now().difference(lastActivity) >= stallTimeout) {
          stalled = true;
          final hung = _process;
          _process = null;
          if (hung != null) {
            // Fire-and-forget: the race below unblocks via stallSignal.
            unawaited(_killTreeOf(hung));
          }
          if (!stallSignal.isCompleted) stallSignal.complete();
        }
      });

      final exitCode = await Future.any<int>([
        proc.exitCode,
        stallSignal.future.then((_) => -1),
      ]);

      if (stalled || exitCode == -1) {
        _errorStream?.add(stallMessage(stallTimeout));
        return null;
      }
      if (exitCode == 0 && downloadedFile != null) {
        _progress?.add(1.0);
        return downloadedFile;
      }
      return null;
    } catch (e) {
      _errorStream?.add(e.toString());
      return null;
    } finally {
      watchdog?.cancel();
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      await _progress?.close();
      _progress = null;
      await _errorStream?.close();
      _errorStream = null;
      _process = null;
    }
  }

  void cancel() {
    final proc = _process;
    _process = null;
    if (proc == null) return;
    // Fire-and-forget tree-kill: taskkill /T /F on Windows (via the
    // injectable runner in tests), direct kill as best-effort fallback so
    // the hung child always dies and the handle never goes stale.
    unawaited(_killTreeOf(proc));
  }

  Future<void> _killTreeOf(Process proc) async {
    final runner = runTreeKill ?? ((exe, args) => Process.run(exe, args));
    try {
      if (Platform.isWindows || runTreeKill != null) {
        await runner('taskkill', ['/PID', '${proc.pid}', '/T', '/F'])
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Best-effort: fall through to the direct kill below.
    }
    try {
      proc.kill();
    } catch (_) {}
  }
}
