import '../commands/project_command.dart';
import 'project_state_snapshot.dart';

final class PersistedTransactionRecord {
  PersistedTransactionRecord({
    required this.planId,
    required this.beforeState,
    required this.afterState,
    required List<CanonicalCommandSummary> commands,
    required this.appliedAt,
    required this.sourceKind,
  }) : commands = List.unmodifiable(commands);

  final String planId;
  final ProjectStateSnapshot beforeState;
  final ProjectStateSnapshot afterState;
  final List<CanonicalCommandSummary> commands;
  final DateTime appliedAt;
  final TransactionSourceKind sourceKind;
  Map<String, Object?> toJson() => {
    'planId': planId,
    'beforeState': beforeState.toJson(),
    'afterState': afterState.toJson(),
    'commands': commands.map((value) => value.toJson()).toList(),
    'appliedAt': appliedAt.toIso8601String(),
    'sourceKind': sourceKind.name,
  };

  factory PersistedTransactionRecord.fromJson(Map<String, Object?> json) =>
      PersistedTransactionRecord(
        planId: json['planId'] as String,
        beforeState: ProjectStateSnapshot.fromJson(
          Map<String, Object?>.from(json['beforeState'] as Map),
        ),
        afterState: ProjectStateSnapshot.fromJson(
          Map<String, Object?>.from(json['afterState'] as Map),
        ),
        commands: (json['commands'] as List<Object?>)
            .map(
              (value) => CanonicalCommandSummary.fromJson(
                Map<String, Object?>.from(value as Map),
              ),
            )
            .toList(),
        appliedAt: DateTime.parse(json['appliedAt'] as String),
        sourceKind: TransactionSourceKind.values.byName(
          json['sourceKind'] as String,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is PersistedTransactionRecord &&
      planId == other.planId &&
      beforeState == other.beforeState &&
      afterState == other.afterState &&
      _commandsEqual(commands, other.commands) &&
      appliedAt == other.appliedAt &&
      sourceKind == other.sourceKind;

  @override
  int get hashCode => Object.hash(
    planId,
    beforeState,
    afterState,
    Object.hashAll(commands),
    appliedAt,
    sourceKind,
  );
}

bool _commandsEqual(
  List<CanonicalCommandSummary> left,
  List<CanonicalCommandSummary> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
