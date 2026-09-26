import 'dart:convert';

import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/entities/sanitized_project_snapshot.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test('validated payload owns exact local immutable candidate data', () {
    final commands = <ProjectCommand>[
      ProjectCommandFactory(
        SequenceIdGenerator(<String>['unused']),
      ).setMuted(clipId: 'clip-1', muted: true),
    ];
    final targetIds = <String>['clip-1'];
    final summaries = <CanonicalCommandSummary>[
      CanonicalCommandSummary(type: 'set_clip_muted', targetIds: targetIds),
    ];
    final candidate = stateWithOneClip();
    final payload = ValidatedPlanPayload(
      commands: commands,
      candidateState: candidate,
      summaries: summaries,
    );

    commands.clear();
    summaries.clear();
    targetIds.clear();

    expect(payload.candidateState, same(candidate));
    expect(payload.commands, hasLength(1));
    expect(payload.summaries, hasLength(1));
    expect(payload.summaries.single.targetIds, <String>['clip-1']);
    expect(
      () => payload.commands.add(
        ProjectCommandFactory(
          SequenceIdGenerator(<String>['tag-2']),
        ).createTag(name: 'A', color: '#112233'),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => payload.summaries.add(
        CanonicalCommandSummary(type: 'create_tag', targetIds: <String>[]),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => payload.summaries.single.targetIds.add('other'),
      throwsUnsupportedError,
    );
    expect(
      () => jsonEncode(payload),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });

  test('a valid provider request carries only explicitly sanitized JSON', () {
    final project = SanitizedProjectSnapshot.fromDocument(
      documentWithOneClip(),
    ).toProviderJson();
    final request = ModelRequest(
      providerId: 'provider',
      modelId: 'model',
      messages: <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'project': project},
      ],
    );

    expect(request.messages.single['project'], project);
    expect(request.messages.single.containsKey('payload'), isFalse);
    expect(request.messages.single.containsKey('candidateState'), isFalse);
    expect(request.messages.single.containsKey('commands'), isFalse);
    expect(request.messages.single.containsKey('summaries'), isFalse);
  });

  test(
    'a provider request rejects local payloads at every JSON nesting level',
    () {
      final payload = _payload();
      for (final message in <Map<String, Object?>>[
        <String, Object?>{'payload': payload},
        <String, Object?>{
          'context': <String, Object?>{'payload': payload},
        },
        <String, Object?>{
          'context': <Object?>[payload],
        },
      ]) {
        expect(
          () => ModelRequest(
            providerId: 'provider',
            modelId: 'model',
            messages: <Map<String, Object?>>[message],
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('edit plan transition matrix retains payload only where permitted', () {
    final payload = _payload();
    final findingInput = <ValidationFinding>[
      ValidationFinding(
        code: 'apply_failed',
        message: 'Could not apply the plan',
      ),
    ];
    final draft = EditPlan.draft(
      id: 'plan-1',
      summary: 'Trim the opening',
      baseProjectId: 'project-1',
      baseRevision: 3,
    );
    final valid = draft.validate(payload);
    final approved = valid.approve();
    final appliedFromValid = valid.apply();
    final appliedFromApproved = approved.apply();
    final rejected = valid.reject(findingInput);
    final cancelled = approved.cancel();
    final revised = valid.revise();
    final failedDraft = draft.fail(findingInput);
    final failedValid = valid.fail(findingInput);
    final failedApproved = approved.fail(findingInput);
    final failedBeforeValidation = EditPlan.failedBeforeValidation(
      id: 'plan-2',
      summary: 'Unable to parse',
      baseProjectId: 'project-1',
      baseRevision: 3,
    );
    findingInput.clear();

    expect(valid.status, EditPlanStatus.valid);
    for (final plan in <EditPlan>[
      draft,
      valid,
      approved,
      appliedFromValid,
      appliedFromApproved,
      rejected,
      cancelled,
      revised,
      failedDraft,
      failedValid,
      failedApproved,
      failedBeforeValidation,
    ]) {
      expect(plan.baseProjectId, 'project-1');
    }
    expect(valid.payload, same(payload));
    expect(approved.payload, same(payload));
    expect(appliedFromValid.payload, same(payload));
    expect(appliedFromApproved.payload, same(payload));
    expect(rejected.payload, isNull);
    expect(cancelled.payload, isNull);
    expect(revised.payload, isNull);
    expect(failedDraft.payload, isNull);
    expect(failedBeforeValidation.payload, isNull);
    expect(failedValid.payload, same(payload));
    expect(failedApproved.payload, same(payload));
    expect(rejected.findings, hasLength(1));
    expect(() => rejected.findings.add(_finding()), throwsUnsupportedError);
    for (final terminal in <EditPlan>[
      rejected,
      cancelled,
      revised,
      failedDraft,
      failedValid,
      failedApproved,
      failedBeforeValidation,
      appliedFromValid,
      appliedFromApproved,
    ]) {
      expect(() => terminal.validate(payload), throwsStateError);
      expect(() => terminal.approve(), throwsStateError);
      expect(() => terminal.apply(), throwsStateError);
    }
  });

  test(
    'edit plans reject invalid identifiers summaries and base revisions',
    () {
      expect(
        () => EditPlan.draft(
          id: '',
          summary: 'Summary',
          baseProjectId: 'project',
          baseRevision: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => EditPlan.draft(
          id: 'plan',
          summary: 'bad\nsummary',
          baseProjectId: 'project',
          baseRevision: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => EditPlan.draft(
          id: 'plan',
          summary: 'Summary',
          baseProjectId: 'project',
          baseRevision: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => EditPlan.draft(
          id: 'plan',
          summary: 'Summary',
          baseProjectId: '',
          baseRevision: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => EditPlan.draft(
          id: 'plan',
          summary: 'Summary',
          baseProjectId: 'project\nsecret',
          baseRevision: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  test('rejected plan summaries are absent from argument diagnostics', () {
    const summarySecret = r'PLAN_SUMMARY_SECRET_C:\private\project';

    expect(
      _argumentErrorText(
        () => EditPlan.draft(
          id: 'plan',
          summary: '$summarySecret\n',
          baseProjectId: 'project',
          baseRevision: 0,
        ),
      ),
      isNot(contains(summarySecret)),
    );
  });

  test('rejected project identities do not leak in argument diagnostics', () {
    const projectSecret = r'PROJECT_ID_SECRET_C:\private\project';
    expect(
      _argumentErrorText(
        () => EditPlan.draft(
          id: 'plan',
          summary: 'Summary',
          baseProjectId: '$projectSecret\n',
          baseRevision: 0,
        ),
      ),
      isNot(contains(projectSecret)),
    );
  });
}

String _argumentErrorText(void Function() action) {
  try {
    action();
  } on ArgumentError catch (error) {
    return error.toString();
  }
  throw StateError('Expected an argument error');
}

ValidatedPlanPayload _payload() => ValidatedPlanPayload(
  commands: <ProjectCommand>[
    ProjectCommandFactory(
      SequenceIdGenerator(<String>['unused']),
    ).setMuted(clipId: 'clip-1', muted: true),
  ],
  candidateState: stateWithOneClip(),
  summaries: <CanonicalCommandSummary>[
    CanonicalCommandSummary(
      type: 'set_clip_muted',
      targetIds: <String>['clip-1'],
    ),
  ],
);

ValidationFinding _finding() =>
    ValidationFinding(code: 'invalid', message: 'Invalid input');
