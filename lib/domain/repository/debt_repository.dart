import 'package:expense_budget_manager/domain/model/debt.dart';

abstract class DebtRepository {
  /// Debts with computed progress, re-emitting when debts or transactions
  /// change.
  Stream<List<DebtProgress>> watchAll();

  Future<Debt?> getById(int id);

  Future<int> upsert({
    int? id,
    required String name,
    String? creditor,
    required int totalAmountMinor,
    required int monthlyPaymentMinor,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
    required int accountId,
    int? categoryId,
  });

  /// Deletes the debt. Historical generated payments are kept (their debt link
  /// is set null by the FK) — documented Feature 4 policy.
  Future<void> delete(int id);

  /// Generates any due monthly payments for all active debts. Idempotent: never
  /// creates a second payment for a cycle already generated, and catches up all
  /// missed cycles since the last run. Returns the number of payments created.
  Future<int> runDueDebts({DateTime? now});
}
