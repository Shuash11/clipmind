import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_plan_notifier.dart';
import 'edit_plan_state.dart';
import 'edit_plan_transaction_gateway.dart';

final editPlanSubmitterProvider = Provider<EditPlanSubmitter>((ref) {
  return (command, token) async => const Failure<EditPlan>(
    ProjectValidationFailure('Agent planning is not configured.'),
  );
});

final editPlanReplannerProvider = Provider<EditPlanReplanner>((ref) {
  return (prior, instruction, token) async => const Failure<EditPlan>(
    ProjectValidationFailure('Agent planning is not configured.'),
  );
});

final editPlanTransactionGatewayProvider = Provider<EditPlanTransactionGateway>(
  (ref) => const UnavailableEditPlanTransactionGateway(),
);

final editPlanCancellationControllerFactoryProvider =
    Provider<EditPlanCancellationControllerFactory>(
      (ref) => CancellationController.new,
    );

final editPlanNotifierProvider =
    StateNotifierProvider<EditPlanNotifier, EditPlanState>((ref) {
      final notifier = EditPlanNotifier(
        submitter: ref.watch(editPlanSubmitterProvider),
        replanner: ref.watch(editPlanReplannerProvider),
        transactionGateway: ref.watch(editPlanTransactionGatewayProvider),
        cancellationControllerFactory: ref.watch(
          editPlanCancellationControllerFactoryProvider,
        ),
      );
      return notifier;
    });
