import 'dart:io';

import 'package:clipmind/core/results/result.dart';

final class LocalSmokeLaunchConfiguration {
  const LocalSmokeLaunchConfiguration({
    required this.fixture,
    required this.report,
  });

  final File fixture;
  final File report;

  static Result<LocalSmokeLaunchConfiguration> parse(List<String> arguments) {
    try {
      return _parse(arguments);
    } catch (_) {
      return _failure();
    }
  }

  static Result<LocalSmokeLaunchConfiguration> _parse(List<String> arguments) {
    String? fixturePath;
    String? reportPath;
    var markerCount = 0;

    for (final argument in arguments) {
      if (argument == '--clipmind-local-smoke') {
        markerCount++;
      } else if (argument.startsWith('--fixture=')) {
        if (fixturePath != null) return _failure();
        final value = argument.substring('--fixture='.length);
        if (value.isEmpty) return _failure();
        fixturePath = value;
      } else if (argument.startsWith('--report=')) {
        if (reportPath != null) return _failure();
        final value = argument.substring('--report='.length);
        if (value.isEmpty) return _failure();
        reportPath = value;
      } else {
        return _failure();
      }
    }

    if (markerCount != 1 || fixturePath == null || reportPath == null) {
      return _failure();
    }

    final fixture = File(fixturePath);
    final report = File(reportPath);
    if (!fixture.isAbsolute || !_hasExtension(fixture.path, '.cmproj')) {
      return _failure();
    }
    if (!_isExistingRegularFile(fixture)) return _failure();

    if (!report.isAbsolute || !_hasExtension(report.path, '.json')) {
      return _failure();
    }
    if (_isExistingFileSystemEntity(report)) return _failure();
    if (!_hasDirectSystemTempParent(reportPath)) return _failure();

    return Success<LocalSmokeLaunchConfiguration>(
      LocalSmokeLaunchConfiguration(fixture: fixture, report: report),
    );
  }

  static bool _hasExtension(String path, String extension) =>
      path.toLowerCase().endsWith(extension);

  static bool _isExistingRegularFile(File file) {
    try {
      return FileSystemEntity.typeSync(file.path, followLinks: false) ==
          FileSystemEntityType.file;
    } on FileSystemException {
      return false;
    }
  }

  static bool _isExistingFileSystemEntity(File file) {
    try {
      return FileSystemEntity.typeSync(file.path, followLinks: false) !=
          FileSystemEntityType.notFound;
    } on FileSystemException {
      return true;
    }
  }

  static bool _hasDirectSystemTempParent(String reportPath) {
    if (RegExp(r'(^|[\\/])\.{1,2}(?=[\\/]|$)').hasMatch(reportPath)) {
      return false;
    }
    final parent = _normalizeLexicalPath(File(reportPath).parent.path);
    final systemTemp = _normalizeLexicalPath(
      Directory.systemTemp.absolute.path,
    );
    return parent == systemTemp;
  }

  static String _normalizeLexicalPath(String path) {
    var normalized = path.replaceAll('/', Platform.pathSeparator);
    while (normalized.length > 1 &&
        normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static Failure<LocalSmokeLaunchConfiguration> _failure() =>
      const Failure<LocalSmokeLaunchConfiguration>(LocalSmokeLaunchFailure());
}

final class LocalSmokeLaunchFailure extends AppFailure {
  const LocalSmokeLaunchFailure()
    : super(
        'local_smoke_launch_invalid',
        'Local smoke launch configuration is invalid.',
      );
}
