import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/status_providers.dart';

class _ScriptProvider extends LlmProvider {
  final StreamController<ConnectionStatus> health =
      StreamController<ConnectionStatus>.broadcast();

  @override
  String get id => 'script';

  @override
  Future<List<String>> availableModels() async => ['script'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionStatus> watchConnection() => health.stream;
}

class _FakeRegistry extends ProviderRegistry {
  final LlmProvider? active;
  _FakeRegistry(this.active);

  @override
  Future<LlmProvider?> getActiveProvider() async => active;
}

class _StubResolver extends FfmpegBinaryResolver {
  final String? value;
  final bool throws;
  _StubResolver({this.value, this.throws = false});

  @override
  String? resolveFfmpeg({String? settingsPath}) {
    if (throws) throw StateError('no resolver here');
    return value;
  }
}

void main() {
  group('providerHealthProvider', () {
    test('emits the active provider connection status', () async {
      final provider = _ScriptProvider();
      addTearDown(provider.health.close);
      final container = ProviderContainer(
        overrides: [
          providerRegistryProvider.overrideWithValue(
            _FakeRegistry(provider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final events = <ConnectionStatus>[];
      final sub = container.listen<AsyncValue<ConnectionStatus>>(
        providerHealthProvider,
        (previous, next) {
          final value = next.valueOrNull;
          if (value != null) events.add(value);
        },
      );
      // Let the provider resolve the registry and subscribe first:
      // broadcast events sent earlier would be lost.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      provider.health.add(ConnectionStatus.connecting);
      provider.health.add(ConnectionStatus.connected);
      for (var i = 0; i < 50 && events.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      sub.close();

      expect(events, contains(ConnectionStatus.connecting));
      expect(events.last, equals(ConnectionStatus.connected));
    });

    test('null provider yields disconnected without throwing', () async {
      final container = ProviderContainer(
        overrides: [
          providerRegistryProvider.overrideWithValue(_FakeRegistry(null)),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(providerHealthProvider.future);
      expect(first, equals(ConnectionStatus.disconnected));
      expect(
        container.read(providerHealthProvider).valueOrNull,
        equals(ConnectionStatus.disconnected),
      );
    });
  });

  group('ffmpegBinaryAvailableProvider', () {
    test('true when the resolver finds a binary', () async {
      final container = ProviderContainer(
        overrides: [
          ffmpegBinaryResolverProvider.overrideWithValue(
            _StubResolver(value: '/usr/bin/ffmpeg'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ffmpegBinaryAvailableProvider.future),
        isTrue,
      );
    });

    test('false when no binary is found', () async {
      final container = ProviderContainer(
        overrides: [
          ffmpegBinaryResolverProvider.overrideWithValue(
            _StubResolver(value: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ffmpegBinaryAvailableProvider.future),
        isFalse,
      );
    });

    test('resolver failure reads as unavailable, never throws', () async {
      final container = ProviderContainer(
        overrides: [
          ffmpegBinaryResolverProvider.overrideWithValue(
            _StubResolver(throws: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ffmpegBinaryAvailableProvider.future),
        isFalse,
      );
    });
  });
}
