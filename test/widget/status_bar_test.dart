import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/presentation/editor/widgets/status_bar.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/status_providers.dart';
import 'package:drift/native.dart';

/// Stub resolver: no dart:io (sync Process/File calls are slow/fragile in
/// the sandbox); returns a fixed path (or null = missing).
class _StubResolver extends FfmpegBinaryResolver {
  _StubResolver(this.path);

  final String? path;

  @override
  String? resolveFfmpeg({String? settingsPath}) => path;
}

/// Retry fake: every [save] succeeds and is counted; the file/DB layers are
/// never touched (path_provider hangs in this sandbox).
class _RecordingProjectRepository extends ProjectRepository {
  _RecordingProjectRepository({required AppDatabase db}) : super(db);

  int saveCalls = 0;

  @override
  Future<void> save(Project project) async {
    saveCalls++;
  }
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test project',
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  );
}

ProviderContainer _container({
  ConnectionStatus health = ConnectionStatus.connected,
  bool ffmpeg = true,
  String? model,
  bool modelLoading = false,
  ProjectRepository? repository,
}) {
  final container = ProviderContainer.test(
    overrides: [
      providerHealthProvider.overrideWith((ref) => Stream.value(health)),
      ffmpegBinaryResolverProvider.overrideWithValue(
        _StubResolver(ffmpeg ? '/fake/ffmpeg.exe' : null),
      ),
      if (modelLoading)
        resolvedModelNameProvider.overrideWith(
          (ref) => Completer<String?>().future,
        )
      else
        resolvedModelNameProvider.overrideWith((ref) async => model),
      if (repository != null)
        projectRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: StatusBar())),
    ),
  );
}

void main() {
  testWidgets('StatusBar shows connected provider and FFmpeg pills', (
    WidgetTester tester,
  ) async {
    final container = _container(
      health: ConnectionStatus.connected,
      ffmpeg: true,
    );
    await _pump(tester, container);
    await tester.pump();

    // No compat model resolves: plain label, no tooltip.
    expect(find.text('AI connected'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.text('FFmpeg ready'), findsOneWidget);
    // Idle run state: the agent pill is hidden.
    expect(find.byKey(const ValueKey('status-agent-pill')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar shows the resolved model suffix with a tooltip', (
    WidgetTester tester,
  ) async {
    final container = _container(
      model: 'meta-llama/Llama-3.3-70B-Instruct',
    );
    await _pump(tester, container);
    await tester.pump();

    // The id truncates to 24 chars + an ellipsis; the tooltip carries the
    // full name.
    expect(
      find.text('AI connected · meta-llama/Llama-3.3-70B…'),
      findsOneWidget,
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'AI connected · meta-llama/Llama-3.3-70B-Instruct',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar keeps the plain label while the model resolves', (
    WidgetTester tester,
  ) async {
    final container = _container(modelLoading: true);
    await _pump(tester, container);
    await tester.pump();

    expect(find.text('AI connected'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar shows Provider offline for a failing provider', (
    WidgetTester tester,
  ) async {
    final container = _container(health: ConnectionStatus.disconnected);
    await _pump(tester, container);
    await tester.pump();

    expect(find.text('Provider offline'), findsOneWidget);
    expect(find.text('AI connected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar shows FFmpeg missing when the resolver fails', (
    WidgetTester tester,
  ) async {
    final container = _container(ffmpeg: false);
    await _pump(tester, container);
    await tester.pump();

    expect(find.text('FFmpeg missing'), findsOneWidget);
    expect(find.text('FFmpeg ready'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar shows a spinner pill while the agent runs', (
    WidgetTester tester,
  ) async {
    final container = _container();
    container.read(agentRunControllerProvider.notifier).state =
        AgentRunState.running;
    await _pump(tester, container);
    await tester.pump();

    expect(find.byKey(const ValueKey('status-agent-pill')), findsOneWidget);
    expect(find.text('AI working…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Three pills max: provider + ffmpeg + agent.
    expect(find.text('AI connected'), findsOneWidget);
    expect(find.text('FFmpeg ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar shows Plan ready while a plan awaits review', (
    WidgetTester tester,
  ) async {
    final container = _container();
    container.read(agentRunControllerProvider.notifier).state =
        AgentRunState.planReady;
    await _pump(tester, container);
    await tester.pump();

    expect(find.text('Plan ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar does not overflow with a long model id', (
    WidgetTester tester,
  ) async {
    final container = _container(model: 'meta-llama/Llama-3.3-70B-Instruct');
    // Test-font glyphs are full-em wide; production metrics fit far below
    // this width. 900 gives solid margin for the truncated label + pills.
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester, container);
    await tester.pump();

    // Truncated label + both pills fit; no overflow.
    expect(
      find.text('AI connected · meta-llama/Llama-3.3-70B…'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar does not overflow at a narrow width', (
    WidgetTester tester,
  ) async {
    final container = _container();
    container.read(agentRunControllerProvider.notifier).state =
        AgentRunState.running;
    tester.view.physicalSize = const Size(720, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester, container);
    await tester.pump();

    // All three pills visible, no overflow.
    expect(find.byKey(const ValueKey('status-agent-pill')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar hides the save-failure pill while persistence is '
      'healthy', (WidgetTester tester) async {
    final container = _container();
    await _pump(tester, container);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('status-save-failure-pill')),
      findsNothing,
    );
    expect(find.text('Changes not saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusBar shows the save-failure pill with the reason', (
    WidgetTester tester,
  ) async {
    final container = _container();
    container.read(projectSaveFailureProvider.notifier).state =
        ProjectSaveFailure(
          message: 'The project could not be saved to disk.',
          failedAt: DateTime(2026, 10, 8),
        );
    await _pump(tester, container);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('status-save-failure-pill')),
      findsOneWidget,
    );
    expect(find.text('Changes not saved'), findsOneWidget);
    // Only the failure pill carries a tooltip here (no model resolved).
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('The project could not be saved to disk.'));
    expect(tooltip.message, contains('retried with your next edit'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the save-failure pill retries and clears it', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _RecordingProjectRepository(db: db);
    final container = _container(repository: repository);
    container.read(projectProvider.notifier).setProject(_project());
    container.read(projectSaveFailureProvider.notifier).state =
        ProjectSaveFailure(
          message: 'The project could not be saved to disk.',
          failedAt: DateTime(2026, 10, 8),
        );
    await _pump(tester, container);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('status-save-failure-pill')),
    );
    await tester.pump();

    // The retry went through the bridge to the repository and succeeded.
    expect(repository.saveCalls, 1);
    expect(container.read(projectSaveFailureProvider), isNull);
    expect(
      find.byKey(const ValueKey('status-save-failure-pill')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
