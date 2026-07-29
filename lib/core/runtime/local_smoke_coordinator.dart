import 'package:clipmind/core/runtime/local_smoke_reporter.dart';

final class LocalSmokeCoordinator {
  factory LocalSmokeCoordinator({required LocalSmokeReporter reporter}) =>
      LocalSmokeCoordinator._(reporter);

  LocalSmokeCoordinator._(this._reporter);

  final LocalSmokeReporter _reporter;
  var _projectLoaded = false;
  var _providersRendered = false;
  var _timelineRendered = false;
  var _terminal = false;

  Future<void> onProjectLoaded() async {
    if (_terminal) return;
    _projectLoaded = true;
    await _writeSuccessIfReady();
  }

  Future<void> onProvidersRendered() async {
    if (_terminal) return;
    _providersRendered = true;
    await _writeSuccessIfReady();
  }

  Future<void> onTimelineRendered() async {
    if (_terminal) return;
    _timelineRendered = true;
    await _writeSuccessIfReady();
  }

  Future<void> onFlutterError(Object error) async {
    if (_terminal) return;
    await _write(flutterError: 'flutter_error');
  }

  Future<void> _writeSuccessIfReady() async {
    if (_projectLoaded && _providersRendered && _timelineRendered) {
      await _write();
    }
  }

  Future<void> _write({String? flutterError}) async {
    if (_terminal) return;
    _terminal = true;
    await _reporter.write(<String, Object?>{
      'projectLoaded': _projectLoaded,
      'providersRendered': _providersRendered,
      'timelineRendered': _timelineRendered,
      'flutterError': flutterError,
    });
  }
}
