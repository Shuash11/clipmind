import 'dart:convert';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/services/malformed_output_repair_policy.dart';
import 'package:clipmind/features/agent/domain/services/agent_planning_service.dart';
import 'package:clipmind/features/agent/domain/services/tool_call_validator.dart';
import 'package:clipmind/features/agent/data/provider_tool_call_normalizer.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test('allows one repair callback per policy instance', () async {
    final policy = MalformedOutputRepairPolicy();
    final request = ModelRequest(
      providerId: 'provider',
      modelId: 'model',
      messages: const [],
    );
    final token = CancellationController().token;
    var calls = 0;
    Future<Result<ModelResponse>> complete(
      ModelRequest value,
      CancellationToken token,
    ) async {
      calls++;
      expect(value.providerId, 'provider');
      expect(value.modelId, 'model');
      return Success(ModelResponse(modelId: 'model', content: '{}'));
    }

    final first = await policy.repair(
      originalRequest: request,
      findings: [
        ValidationFinding(code: 'invalid_json', message: 'Safe finding.'),
      ],
      complete: complete,
      token: token,
    );
    final second = await policy.repair(
      originalRequest: request,
      findings: const [],
      complete: complete,
      token: token,
    );
    expect(first, isA<Success<ModelResponse>>());
    expect(second, isNull);
    expect(calls, 1);
  });

  test(
    'repair request preserves identity and excludes unsafe diagnostic values',
    () async {
      final policy = MalformedOutputRepairPolicy();
      final token = CancellationController().token;
      final original = ModelRequest(
        providerId: 'provider',
        modelId: 'model',
        idempotencyKey: 'key',
        tools: const [],
        messages: const [
          {'role': 'user', 'content': 'sanitized'},
        ],
      );
      ModelRequest? repair;
      await policy.repair(
        originalRequest: original,
        findings: [
          ValidationFinding(
            code: 'invalid_arguments',
            message: 'Safe',
            argumentPath: 'placements[0].clipId',
          ),
        ],
        complete: (request, _) async {
          repair = request;
          return Success(ModelResponse(modelId: 'model', content: '{}'));
        },
        token: token,
      );
      expect(repair!.providerId, original.providerId);
      expect(repair!.modelId, original.modelId);
      expect(repair!.idempotencyKey, original.idempotencyKey);
      expect(repair!.tools, original.tools);
      expect(
        repair!.messages.take(original.messages.length).toList(),
        original.messages,
      );
      final encoded = repair!.messages.last['content'] as String;
      expect(encoded, contains('invalid_arguments'));
      expect(encoded, contains('placements[0].clipId'));
      expect(encoded, isNot(contains(r'C:\secret')));
      for (final forbidden in [
        r'FINDING_SECRET_C:\private',
        'sourcePath',
        'outputDirectory',
        'history',
        'ValidatedPlanPayload',
        'candidate',
        'commands',
        'summaries',
      ]) {
        expect(encoded, isNot(contains(forbidden)));
      }
    },
  );

  test(
    'planning returns a valid local plan without repair for valid first output',
    () async {
      var completions = 0;
      final service = AgentPlanningService(
        registry: EditorToolRegistry.standard(),
        normalizer: ProviderToolCallNormalizer(),
        validator: ToolCallValidator(
          registry: EditorToolRegistry.standard(),
          commandFactory: ProjectCommandFactory(SequenceIdGenerator([])),
          commandExecutor: ProjectCommandExecutor.standard(),
        ),
        complete: (request, _) async {
          completions++;
          final requestText = request.messages.last['content'] as String;
          expect(requestText, isNot(contains(r'C:\media\source.mp4')));
          expect(requestText, isNot(contains(r'C:\exports')));
          return Success(
            ModelResponse(
              modelId: request.modelId,
              content: 'safe',
              toolCalls: [
                NormalizedModelToolCall(
                  id: 'call',
                  name: 'set_clip_brightness',
                  arguments: {'clipId': 'clip-1', 'brightness': 0},
                ),
              ],
            ),
          );
        },
        planIdFactory: () => 'plan-1',
      );
      final outcome = await service.plan(
        AgentPlanningRequest(
          providerId: 'provider',
          modelId: 'model',
          userCommand: 'Make it brighter',
          document: documentWithOneClip(revision: 7),
          cancellationToken: CancellationController().token,
        ),
      );
      final plan = (outcome as Success).value;
      expect(completions, 1);
      expect(plan.status, EditPlanStatus.valid);
      expect(plan.baseRevision, 7);
      expect(plan.baseProjectId, 'project-1');
      expect(plan.payload, isNotNull);
    },
  );

  test('repair propagates typed completion failure once', () async {
    final policy = MalformedOutputRepairPolicy();
    var callbacks = 0;
    final result = await policy.repair(
      originalRequest: _request(),
      findings: [_finding()],
      token: CancellationController().token,
      complete: (_, _) async {
        callbacks++;
        return const Failure<ModelResponse>(
          ProviderTransportFailure(message: 'typed failure'),
        );
      },
    );
    expect(result, isA<Failure<ModelResponse>>());
    expect((result! as Failure<ModelResponse>).error.message, 'typed failure');
    expect(callbacks, 1);
    expect(policy.callbackCount, 1);
  });

  test('repair maps thrown errors to a safe transport failure', () async {
    const secret = r'THROWN_SECRET_C:\private\token';
    final result = await MalformedOutputRepairPolicy().repair(
      originalRequest: _request(),
      findings: [_finding()],
      token: CancellationController().token,
      complete: (_, _) async => throw StateError(secret),
    );
    final failure = result! as Failure<ModelResponse>;
    expect(failure.error, isA<ProviderTransportFailure>());
    expect(failure.error.toString(), isNot(contains(secret)));
  });

  test(
    'pre-cancelled repair calls no callback and consumes only its local allowance',
    () async {
      final controller = CancellationController()..cancel();
      final policy = MalformedOutputRepairPolicy();
      var callbacks = 0;
      final result = await policy.repair(
        originalRequest: _request(),
        findings: [_finding()],
        token: controller.token,
        complete: (_, _) async {
          callbacks++;
          return Success(_validResponse());
        },
      );
      expect(
        (result! as Failure<ModelResponse>).error,
        isA<ProviderCancellationFailure>(),
      );
      expect(callbacks, 0);
      expect(policy.callbackCount, 1);
      expect(policy.canRepair, isFalse);
    },
  );

  test(
    'repair observes cancellation after an ignored-token callback returns',
    () async {
      final controller = CancellationController();
      final result = await MalformedOutputRepairPolicy().repair(
        originalRequest: _request(),
        findings: [_finding()],
        token: controller.token,
        complete: (_, _) async {
          controller.cancel();
          return Success(_validResponse());
        },
      );
      expect(
        (result! as Failure<ModelResponse>).error,
        isA<ProviderCancellationFailure>(),
      );
    },
  );

  test('independent repair policies each permit one callback', () async {
    var callbacks = 0;
    Future<Result<ModelResponse>> complete(
      ModelRequest _,
      CancellationToken _,
    ) async {
      callbacks++;
      return Success(_validResponse());
    }

    for (final policy in [
      MalformedOutputRepairPolicy(),
      MalformedOutputRepairPolicy(),
    ]) {
      expect(
        await policy.repair(
          originalRequest: _request(),
          findings: [_finding()],
          complete: complete,
          token: CancellationController().token,
        ),
        isA<Success<ModelResponse>>(),
      );
      expect(
        await policy.repair(
          originalRequest: _request(),
          findings: [_finding()],
          complete: complete,
          token: CancellationController().token,
        ),
        isNull,
      );
    }
    expect(callbacks, 2);
  });

  test('invalid first output repairs once into a valid payload', () async {
    var calls = 0;
    final service = _service((_, _) async {
      calls++;
      return calls == 1
          ? Success(ModelResponse(modelId: 'model', content: 'not json'))
          : Success(_validResponse());
    });
    final result = await service.plan(
      _submission(CancellationController().token, revision: 3),
    );
    final plan = _success(result);
    expect(calls, 2);
    expect(plan.status, EditPlanStatus.valid);
    expect(plan.baseRevision, 3);
    expect(plan.baseProjectId, 'project-1');
    expect(plan.payload, isNotNull);
  });

  test(
    'two malformed outputs reject the plan and do not request a third completion',
    () async {
      var calls = 0;
      final result = await _service((_, _) async {
        calls++;
        return Success(
          ModelResponse(modelId: 'model', content: 'malformed response'),
        );
      }).plan(_submission(CancellationController().token));
      final plan = _success(result);
      expect(calls, 2);
      expect(plan.status, EditPlanStatus.rejected);
      expect(plan.baseProjectId, 'project-1');
      expect(plan.payload, isNull);
      expect(plan.findings, isNotEmpty);
      expect(plan.findings.join(' '), isNot(contains('malformed response')));
    },
  );

  test(
    'planning propagates provider failure and cancellation without repair',
    () async {
      var failures = 0;
      final failed = await _service((_, _) async {
        failures++;
        return const Failure<ModelResponse>(
          ProviderTransportFailure(message: 'offline'),
        );
      }).plan(_submission(CancellationController().token));
      expect((failed as Failure).error, isA<ProviderTransportFailure>());
      expect(failures, 1);

      final preCancelled = CancellationController()..cancel();
      var preCalls = 0;
      final cancelled = await _service((_, _) async {
        preCalls++;
        return Success(_validResponse());
      }).plan(_submission(preCancelled.token));
      expect((cancelled as Failure).error, isA<ProviderCancellationFailure>());
      expect(preCalls, 0);

      final during = CancellationController();
      final cancelledDuring = await _service((_, _) async {
        during.cancel();
        return Success(_validResponse());
      }).plan(_submission(during.token));
      expect(
        (cancelledDuring as Failure).error,
        isA<ProviderCancellationFailure>(),
      );
    },
  );

  test(
    'invalid planning identities and command have zero completion calls',
    () async {
      var calls = 0;
      final service = _service((_, _) async {
        calls++;
        return Success(_validResponse());
      });
      for (final submission in [
        _submission(CancellationController().token, command: ''),
        _submission(CancellationController().token, providerId: ''),
        _submission(CancellationController().token, modelId: ''),
      ]) {
        final plan = _success(await service.plan(submission));
        expect(plan.status, EditPlanStatus.rejected);
        expect(plan.baseProjectId, 'project-1');
        expect(plan.payload, isNull);
      }
      expect(calls, 0);
    },
  );

  test(
    'planning has no eager request and each session receives one repair allowance',
    () async {
      var calls = 0;
      final requests = <ModelRequest>[];
      final service = _service((request, _) async {
        calls++;
        requests.add(request);
        return calls.isOdd
            ? Success(
                ModelResponse(
                  modelId: 'model',
                  content: 'MALFORMED_BODY_SECRET',
                ),
              )
            : Success(_validResponse());
      });
      expect(calls, 0);
      final one = await service.plan(
        _submission(CancellationController().token),
      );
      final two = await service.plan(
        _submission(CancellationController().token),
      );
      expect(_success(one).status, EditPlanStatus.valid);
      expect(_success(two).status, EditPlanStatus.valid);
      expect(calls, 4);
      for (final request in requests) {
        final userMessages = request.messages
            .where((message) => message['role'] == 'user')
            .map((message) => message['content'] as String)
            .toList();
        expect(userMessages, isNotEmpty);
        _expectSafeProviderJson(jsonDecode(userMessages.first));
        if (userMessages.length == 2) {
          _expectSafeRepairJson(jsonDecode(userMessages.last));
        } else {
          expect(userMessages, hasLength(1));
        }
      }
    },
  );
}

ValidationFinding _finding() => ValidationFinding(
  code: 'invalid_arguments',
  message: r'FINDING_SECRET_C:\private\sourcePath',
  argumentPath: 'placements[0].clipId',
);

ModelRequest _request() => ModelRequest(
  providerId: 'provider',
  modelId: 'model',
  idempotencyKey: 'key',
  tools: EditorToolRegistry.standard().toModelToolDefinitions(),
  messages: const [
    {'role': 'system', 'content': 'sanitized system'},
    {'role': 'user', 'content': 'sanitized request'},
  ],
);

ModelResponse _validResponse() => ModelResponse(
  modelId: 'model',
  content: 'safe',
  toolCalls: [
    NormalizedModelToolCall(
      id: 'call',
      name: 'set_clip_brightness',
      arguments: {'clipId': 'clip-1', 'brightness': 0},
    ),
  ],
);

AgentPlanningService _service(PlanningCompletion complete) =>
    AgentPlanningService(
      registry: EditorToolRegistry.standard(),
      normalizer: ProviderToolCallNormalizer(),
      validator: ToolCallValidator(
        registry: EditorToolRegistry.standard(),
        commandFactory: ProjectCommandFactory(SequenceIdGenerator([])),
        commandExecutor: ProjectCommandExecutor.standard(),
      ),
      complete: complete,
      planIdFactory: () => 'plan-1',
      repairPolicyFactory: MalformedOutputRepairPolicy.new,
    );

AgentPlanningRequest _submission(
  CancellationToken token, {
  int revision = 0,
  String command = 'Adjust brightness',
  String providerId = 'provider',
  String modelId = 'model',
}) => AgentPlanningRequest(
  providerId: providerId,
  modelId: modelId,
  userCommand: command,
  document: documentWithOneClip(revision: revision),
  cancellationToken: token,
);

EditPlan _success(Result<EditPlan> value) => (value as Success<EditPlan>).value;

void _expectSafeProviderJson(Object? value) {
  const prohibitedKeys = {
    'payload',
    'candidateState',
    'candidate',
    'commands',
    'summaries',
    'history',
    'outputDirectory',
    'sourcePath',
  };
  const prohibitedText = [
    r'C:\media\source.mp4',
    r'C:\exports',
    'ValidatedPlanPayload',
    'MALFORMED_BODY_SECRET',
    r'FINDING_SECRET_C:\private',
  ];
  if (value is Map) {
    for (final entry in value.entries) {
      expect(entry.key, isA<String>());
      expect(prohibitedKeys, isNot(contains(entry.key)));
      _expectSafeProviderJson(entry.value);
    }
  } else if (value is List) {
    for (final item in value) {
      _expectSafeProviderJson(item);
    }
  } else if (value is String) {
    for (final forbidden in prohibitedText) {
      expect(value, isNot(contains(forbidden)));
    }
  }
}

void _expectSafeRepairJson(Object? value) {
  if (value is! Map<Object?, Object?>) {
    fail('Expected a JSON object.');
  }
  final repair = value;
  expect(repair.keys, unorderedEquals(['instruction', 'findings']));
  expect(repair['instruction'], isA<String>());
  _expectSafeProviderJson(repair['instruction']);
  final findings = repair['findings'];
  if (findings is! List<Object?>) {
    fail('Expected JSON finding values.');
  }
  for (final value in findings) {
    if (value is! Map<Object?, Object?>) {
      fail('Expected a JSON finding object.');
    }
    final finding = value;
    expect(
      finding.keys.every((key) => key == 'code' || key == 'argumentPath'),
      isTrue,
    );
    expect(finding['code'], isA<String>());
    _expectSafeProviderJson(finding);
  }
}
