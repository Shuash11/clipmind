import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

class YouTubeImportService {
  /// Typed missing-binary guidance, surfaced on [errors] when `yt-dlp`
  /// cannot be started. Same actionable-message family as the FFmpeg
  /// binary-not-found failures. Mirrors the import guidance dialog: the
  /// official standalone build, placed on PATH — there is no in-app path
  /// setting (and no winget assumption).
  static const missingBinaryMessage =
      'yt-dlp not found — install the official standalone yt-dlp.exe '
      '(Windows) or yt-dlp_macos (macOS) build, then add it to your PATH';

  /// Typed invalid-input guidance, surfaced on [errors] when [import]
  /// receives anything that is not an http(s) URL: empty input,
  /// `--`-prefixed options, or other schemes such as `file://`.
  static const invalidUrlMessage =
      'Only http and https YouTube links are supported — '
      'enter a full video URL';

  /// Stall watchdog window: a healthy yt-dlp emits stdout/stderr lines
  /// regularly, so firing only when no output arrives for [stallTimeout]
  /// means the child is truly hung. No total-duration cap.
  final Duration stallTimeout;

  /// Availability probe window for [checkAvailability]: `yt-dlp --version`
  /// answers at once when the binary is healthy, so a probe that has not
  /// settled within this window is treated as unavailable and its child
  /// is killed.
  final Duration probeTimeout;

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

  /// Generates the fresh uuid-v4 folder name every import downloads into.
  final Uuid _uuid = const Uuid();

  StreamController<double>? _progress;
  StreamController<String>? _errorStream;
  Process? _process;

  /// Single-flight claim: true while an import is between its start and its
  /// completion, so the shared controllers and cancel target above are
  /// never clobbered by a concurrent call.
  bool _inFlight = false;

  YouTubeImportService({
    this.stallTimeout = const Duration(seconds: 120),
    this.probeTimeout = const Duration(seconds: 5),
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

  /// Grace window after the stall watchdog fires: the exit code gets a
  /// brief moment to land so a child that finished naturally in the same
  /// instant the watchdog tripped still yields its file. A child that
  /// never settles resolves to the typed stall failure after this window.
  static const _exitGrace = Duration(milliseconds: 250);

  /// Probes whether `yt-dlp` is installed and runnable — never throws.
  ///
  /// Runs `yt-dlp --version` through the same [startProcess] seam [import]
  /// uses (default `Process.start`), collects stdout, and waits
  /// [probeTimeout]. Every failure — missing binary, non-zero exit, a
  /// timeout, or an unexpected error — resolves to an unavailable
  /// [YtDlpAvailability] carrying [missingBinaryMessage]; a timeout also
  /// kills the hung child. Read-only: it never touches the in-flight
  /// import lifecycle (single-flight, shared controllers, cancel handle).
  Future<YtDlpAvailability> checkAvailability() async {
    try {
      final starter = startProcess;
      final proc = starter != null
          ? await starter('yt-dlp', const ['--version'])
          : await Process.start('yt-dlp', const ['--version']);

      final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
      // Drain stderr immediately: an unread pipe blocks the child once the
      // OS buffer fills, and only stdout carries the version line.
      unawaited(proc.stderr.drain<void>());

      final int exitCode;
      try {
        exitCode = await proc.exitCode.timeout(probeTimeout);
      } on TimeoutException {
        try {
          proc.kill();
        } catch (_) {}
        stdoutFuture.ignore();
        return const YtDlpAvailability.unavailable(missingBinaryMessage);
      }

      final version = (await stdoutFuture).trim();
      if (exitCode != 0 || version.isEmpty) {
        return const YtDlpAvailability.unavailable(missingBinaryMessage);
      }
      return YtDlpAvailability.available(version);
    } on ProcessException {
      return const YtDlpAvailability.unavailable(missingBinaryMessage);
    } catch (_) {
      // Non-throwing contract: an unexpected probe failure reads as
      // unavailable instead of escaping to the caller.
      return const YtDlpAvailability.unavailable(missingBinaryMessage);
    }
  }

  /// Reports an import failure on [errors].
  ///
  /// Emissions raised synchronously (invalid URL input) are deferred to a
  /// microtask: broadcast controllers drop events added while nobody is
  /// listening, so a listener subscribing right after [import] is called
  /// would otherwise miss them. Same pattern as `UrlImportService`.
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

  /// Downloads [url] into [outputDir] and returns the moved file path.
  ///
  /// Every import downloads into a freshly created `{outputDir}/<uuid-v4>`
  /// folder, so two imports — even of same-title videos — can never share a
  /// filename, resume an earlier partial, or silently reuse a pre-existing
  /// file. The returned path is the exact `after_move:filepath` line yt-dlp
  /// printed. Any other outcome (invalid URL, spawn failure, non-zero exit,
  /// stall, cancel, unexpected error) removes the per-import folder; an
  /// invalid URL is rejected before any folder is created.
  ///
  /// Lifecycle: single-flight (a second concurrent [import] throws
  /// [YoutubeImportBusyException]); a stall tree-kills the child and
  /// surfaces the typed stall failure on [errors]; a [cancel] kills the
  /// child and the in-flight import resolves when the killed child's exit
  /// code lands. A child that finishes naturally in the same instant the
  /// watchdog fires still yields its file (grace window below).
  Future<String?> import(String url, String outputDir) async {
    // Single-flight: a second concurrent import would clobber the shared
    // [_progress]/[_errorStream] controllers and the [_process] cancel
    // target — reject instead of clobbering. Synchronous with the claim
    // below, so calls racing to start resolve deterministically.
    if (_inFlight) {
      throw const YoutubeImportBusyException(
        'YouTube import is busy — another download is already running',
      );
    }
    _inFlight = true;
    _progress = StreamController<double>.broadcast();
    _errorStream = StreamController<String>.broadcast();

    Timer? watchdog;
    final stallSignal = Completer<void>();
    var stalled = false;
    var lastActivity = DateTime.now();
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    // Per-import storage is created only after URL validation, so it stays
    // null for rejected input and cleanup can never touch anything.
    Directory? importDir;
    // Set only on the success path: every other outcome removes [importDir].
    var kept = false;

    void markActivity() {
      lastActivity = DateTime.now();
    }

    try {
      // Input hardening: reject anything that is not an http(s) URL —
      // empty input, `--`-prefixed yt-dlp options, other schemes such as
      // `file://` — before spawning. Emitted through [_reportError] so a
      // listener subscribing right after [import] is called still sees it.
      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        _reportError(invalidUrlMessage);
        return null;
      }

      // Fresh per-import folder: yt-dlp's title-based template is only
      // collision-free inside one. In a shared directory an existing final
      // file makes yt-dlp skip the download and print the old file's path
      // (silent wrong-content reuse), and a `.part` left by an earlier
      // attempt gets resumed. A private folder makes both impossible and
      // lets a failed attempt be removed as one unit.
      importDir = Directory('$outputDir/${_uuid.v4()}');
      await importDir.create(recursive: true);

      final args = [
        '--newline',
        '--no-warnings',
        '--print',
        'after_move:filepath',
        '-o',
        '${importDir.path}/%(title)s.%(ext)s',
        '--no-playlist',
        // Upstream-documented end-of-options: the URL is always treated as
        // a URL, never as a yt-dlp option.
        '--',
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

      final watchdogFired = exitCode == -1;

      // Grace window: when the watchdog fires, the exit code gets a brief
      // moment to land so a child that finished naturally in the same
      // instant the watchdog tripped still yields its file.
      var settled = exitCode;
      if (watchdogFired) {
        try {
          settled = await proc.exitCode.timeout(_exitGrace);
        } on TimeoutException {
          // The child never settled its exit code even after the kill.
          settled = -1;
        }
      }

      // Natural exit wins over a same-instant watchdog trip: the
      // `after_move:filepath` line only arrives after the move completed,
      // so a real exit 0 with a downloaded file is never suppressed by the
      // stall message.
      if (settled == 0 && downloadedFile != null) {
        _progress?.add(1.0);
        kept = true;
        return downloadedFile;
      }
      if (watchdogFired) {
        _errorStream?.add(stallMessage(stallTimeout));
        return null;
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
      // Non-success outcomes (rejection, spawn failure, non-zero exit,
      // stall, cancel, unexpected error) leave no partial file or empty
      // folder behind. [_removeImportDir] never throws, so cleanup cannot
      // mask the reported outcome.
      if (!kept && importDir != null) {
        await _removeImportDir(importDir);
      }
      _process = null;
      _inFlight = false;
    }
  }

  /// Deletes the per-import folder, never throwing — cleanup must not mask
  /// the import outcome. Retries briefly because on Windows the recursive
  /// delete can race a just-killed yt-dlp, whose handle on the partial file
  /// may take a few milliseconds to close.
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

  /// Kills the in-flight child, if any, and clears the handle synchronously
  /// (no stale handle survives the kill path — [_killTreeOf] clears it too).
  ///
  /// No typed cancel failure is emitted and no separate cancel signal
  /// unblocks the in-flight [import]: it resolves when the killed child's
  /// exit code lands. Intentional (Phase 3 review): a child that outlives
  /// the kill stays pending until the stall watchdog resolves it.
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
    // Safety net for the kill path: callers clear the shared handle
    // synchronously before awaiting this kill, but the handle is cleared
    // here too so a stale handle can never survive the kill path.
    if (identical(_process, proc)) _process = null;
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

/// Typed result of [YouTubeImportService.checkAvailability]: inspectable
/// and never thrown. [version] is the reported program version when
/// available; [message] carries actionable recovery guidance when not.
class YtDlpAvailability {
  final bool isAvailable;
  final String? version;
  final String? message;

  const YtDlpAvailability.available(String this.version)
      : isAvailable = true,
        message = null;

  const YtDlpAvailability.unavailable(String this.message)
      : isAvailable = false,
        version = null;
}

/// Typed single-flight failure for [YouTubeImportService.import]. Thrown
/// synchronously when a second concurrent import starts while one is in
/// flight (the shared controllers and cancel handle cannot serve two
/// children). Matches the FFmpeg `FfmpegBusyException` pattern; surfaced
/// via the consumer's catch.
class YoutubeImportBusyException implements Exception {
  final String message;
  const YoutubeImportBusyException(this.message);

  @override
  String toString() => 'YoutubeImportBusyException: $message';
}
