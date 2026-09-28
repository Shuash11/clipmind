import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/state/settings_providers.dart';

/// Project-scoped media-analysis cache (Phase 6a).
///
/// Exposes the exact sync callback shapes `ToolExecutionContext` consumes
/// (`readAnalysis`/`writeAnalysis`), backed by the `MediaAnalysis` table.
/// Reads serve the in-memory cache (warmed by [warmUp]); writes update the
/// cache immediately and persist best-effort. Payloads carry a
/// `source_path` stamp used as the row's source path.
class AgentAnalysisPort {
  AgentAnalysisPort({
    required this.db,
    required this.projectId,
  });

  final AppDatabase db;
  final String projectId;

  final Map<String, Map<String, dynamic>> _cache = {};

  /// Sync read for `ToolExecutionContext.readAnalysis`.
  Map<String, dynamic>? read(String kind) => _cache[kind];

  /// Sync write for `ToolExecutionContext.writeAnalysis`.
  void write(String kind, Map<String, dynamic> payload) {
    _cache[kind] = Map<String, dynamic>.from(payload);
    unawaited(_persist(kind));
  }

  /// Preload cached payloads for [clipIds] (`scenes:`/`transcript:` kinds).
  Future<void> warmUp(List<String> clipIds) async {
    for (final clipId in clipIds) {
      for (final prefix in const ['scenes', 'transcript']) {
        final kind = '$prefix:$clipId';
        try {
          final payload = await db.getAnalysisPayload(projectId, kind);
          if (payload != null) {
            _cache[kind] = payload;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _persist(String kind) async {
    try {
      final payload = _cache[kind];
      if (payload == null) return;
      await db.saveAnalysis(projectId: projectId,
        kind: kind,
        sourcePath: payload['source_path'] as String? ?? '',
        payload: payload,
      );
    } catch (_) {}
  }
}

final agentAnalysisPortProvider =
    Provider.family<AgentAnalysisPort, String>((ref, projectId) {
  return AgentAnalysisPort(
    db: ref.read(appDatabaseProvider),
    projectId: projectId,
  );
});

