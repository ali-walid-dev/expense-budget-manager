import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

abstract class TransactionRepository {
  /// Pulse that fires whenever transactions change — for paged lists to refresh.
  Stream<int> watchChangeSignal();

  Stream<List<TransactionWithDetails>> watchRecent(int limit);

  Future<List<TransactionWithDetails>> getPage({
    required int offset,
    required int limit,
    String query = '',
  });

  Stream<List<TransactionWithDetails>> search(String query);

  Future<int> insert({
    required int amountMinor,
    required TransactionType type,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required DateTime dateTime,
    String? note,
    int? recurringId,
  });

  Future<void> update({
    required int id,
    required int amountMinor,
    required TransactionType type,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required DateTime dateTime,
    String? note,
  });

  Future<void> delete(int id);
  Future<int> duplicate(int id);

  /// Totals for a date range.
  Stream<({int income, int expense})> watchTotalsInRange(
      DateTime start, DateTime end);

  /// Used by analytics / budgets.
  Stream<List<CategorySpend>> watchSpendingByCategory(
      DateTime start, DateTime end);

  Stream<List<DailySpend>> watchDailyTrend(DateTime start, DateTime end);

  Future<int> sumSpendInRange({
    required DateTime start,
    required DateTime end,
    int? categoryId,
  });

  /// Generates due transactions from recurring rules. Returns number created.
  Future<int> runDueRecurring({DateTime? now});
}

class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.totalMinor,
  });
  final int categoryId;
  final String categoryName;
  final String colorHex;
  final int totalMinor;
}

class DailySpend {
  const DailySpend({required this.day, required this.totalMinor});
  final DateTime day;
  final int totalMinor;
}

class TransactionDraft {
  const TransactionDraft({
    required this.amountMinor,
    required this.type,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.dateTime,
    required this.note,
    required this.recurring,
    required this.recurringInterval,
  });
  final int amountMinor;
  final TransactionType type;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final DateTime dateTime;
  final String? note;
  final bool recurring;
  final RecurringInterval? recurringInterval;
}
