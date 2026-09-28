import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/presentation/editor/widgets/status_bar.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/status_providers.dart';

/// Stub resolver: no dart:io (sync Process/File calls are slow/fragile in
/// the sandbox); returns a fixed path (or null = missing).
class _StubResolver extends FfmpegBinaryResolver {
  _StubResolver(this.path);

  final String? path;

  @override
  String? resolveFfmpeg({String? settingsPath}) => path;
}

ProviderContainer _container({
  ConnectionStatus health = ConnectionStatus.connected,
  bool ffmpeg = true,
}) {
  final container = ProviderContainer(
    overrides: [
      providerHealthProvider.overrideWith((ref) => Stream.value(health)),
      ffmpegBinaryResolverProvider.overrideWithValue(
        _StubResolver(ffmpeg ? '/fake/ffmpeg.exe' : null),
      ),
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

    expect(find.text('AI connected'), findsOneWidget);
    expect(find.text('FFmpeg ready'), findsOneWidget);
    // Idle run state: the agent pill is hidden.
    expect(find.byKey(const ValueKey('status-agent-pill')), findsNothing);
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
}
