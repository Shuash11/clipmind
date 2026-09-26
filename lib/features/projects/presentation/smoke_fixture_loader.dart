import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/data/project_document_migrator.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';

abstract interface class SmokeFixtureLoader {
  Future<Result<ProjectDocument>> load(File fixture);
}

final class FileSmokeFixtureLoader implements SmokeFixtureLoader {
  factory FileSmokeFixtureLoader({
    ProjectDocumentCodec? codec,
    ProjectDocumentMigrator? migrator,
  }) {
    final resolvedCodec = codec ?? ProjectDocumentCodec();
    return FileSmokeFixtureLoader._(
      resolvedCodec,
      migrator ?? ProjectDocumentMigrator(resolvedCodec),
    );
  }

  FileSmokeFixtureLoader._(this._codec, this._migrator);

  final ProjectDocumentCodec _codec;
  final ProjectDocumentMigrator _migrator;

  @override
  Future<Result<ProjectDocument>> load(File fixture) async {
    try {
      final source = await fixture.readAsString();
      final decoded = _codec.decodeJson(source);
      if (decoded case Success<ProjectDocument>()) return decoded;
      final migrated = _migrator.migrateJson(source);
      if (migrated case Success<ProjectDocument>()) return migrated;
      return _failure();
    } catch (_) {
      return _failure();
    }
  }

  Failure<ProjectDocument> _failure() =>
      const Failure<ProjectDocument>(LocalSmokeFixtureFailure());
}

final class LocalSmokeFixtureFailure extends AppFailure {
  const LocalSmokeFixtureFailure()
    : super(
        'local_smoke_fixture_invalid',
        'Local smoke fixture could not be loaded.',
      );
}
