import 'dart:convert';
import 'dart:io';

abstract interface class LocalSmokeReporter {
  Future<void> write(Map<String, Object?> report);
}

final class FileLocalSmokeReporter implements LocalSmokeReporter {
  FileLocalSmokeReporter(this._file);

  final File _file;

  @override
  Future<void> write(Map<String, Object?> report) async {
    _validate(report);
    await _file.create(exclusive: true);
    final handle = await _file.open(mode: FileMode.writeOnly);
    try {
      await handle.writeString(jsonEncode(report));
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  void _validate(Map<String, Object?> report) {
    const expectedKeys = <String>{
      'projectLoaded',
      'providersRendered',
      'timelineRendered',
      'flutterError',
    };
    if (report.length != expectedKeys.length ||
        !report.keys.every(expectedKeys.contains)) {
      throw ArgumentError.value(
        report,
        'report',
        'Unexpected smoke report schema.',
      );
    }
    if (report['projectLoaded'] is! bool ||
        report['providersRendered'] is! bool ||
        report['timelineRendered'] is! bool) {
      throw ArgumentError.value(
        report,
        'report',
        'Smoke status values must be boolean.',
      );
    }
    final flutterError = report['flutterError'];
    if (flutterError != null &&
        (flutterError is! String ||
            flutterError.isEmpty ||
            flutterError.length > 64 ||
            !RegExp(r'^[a-z0-9_]+$').hasMatch(flutterError))) {
      throw ArgumentError.value(
        report,
        'report',
        'Smoke error code is invalid.',
      );
    }
  }
}
