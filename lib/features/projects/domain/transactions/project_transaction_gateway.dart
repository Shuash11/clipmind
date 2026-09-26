import 'edit_transaction.dart';

abstract interface class ProjectTransactionGateway {
  Future<void> apply(EditTransaction transaction);
}
