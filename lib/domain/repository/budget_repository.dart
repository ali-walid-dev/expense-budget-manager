import 'package:expense_budget_manager/domain/model/budget.dart';

abstract class BudgetRepository {
  Stream<List<Budget>> watchAll();
  Stream<List<BudgetProgress>> watchProgress();

  Future<int> upsert({
    int? id,
    required int amountMinor,
    required BudgetPeriod period,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool carryOver = false,
  });

  Future<void> delete(int id);
}
