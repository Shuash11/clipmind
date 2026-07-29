import 'package:clipmind/core/runtime/local_smoke_coordinator.dart';
import 'package:clipmind/core/runtime/local_smoke_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'writes one success report after all rendering callbacks succeed',
    () async {
      final reporter = _MemoryLocalSmokeReporter();
      final coordinator = LocalSmokeCoordinator(reporter: reporter);

      await coordinator.onTimelineRendered();
      await coordinator.onProjectLoaded();
      await coordinator.onTimelineRendered();
      expect(reporter.reports, isEmpty);

      await coordinator.onProvidersRendered();
      await coordinator.onProjectLoaded();
      await coordinator.onProvidersRendered();

      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single, <String, Object?>{
        'projectLoaded': true,
        'providersRendered': true,
        'timelineRendered': true,
        'flutterError': null,
      });
    },
  );

  test(
    'writes one redacted terminal Flutter error report immediately',
    () async {
      final reporter = _MemoryLocalSmokeReporter();
      final coordinator = LocalSmokeCoordinator(reporter: reporter);

      await coordinator.onProjectLoaded();
      await coordinator.onFlutterError(
        StateError(r'Could not render C:\private\clipmind\fixture.cmproj'),
      );
      await coordinator.onProvidersRendered();
      await coordinator.onTimelineRendered();
      await coordinator.onFlutterError(StateError('another error'));

      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single, <String, Object?>{
        'projectLoaded': true,
        'providersRendered': false,
        'timelineRendered': false,
        'flutterError': 'flutter_error',
      });
    },
  );
}

final class _MemoryLocalSmokeReporter implements LocalSmokeReporter {
  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];

  @override
  Future<void> write(Map<String, Object?> report) async {
    reports.add(Map<String, Object?>.from(report));
  }
}
