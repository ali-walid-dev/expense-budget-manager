import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

class DashboardState {
  const DashboardState({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.remainingBudget,
    required this.budgetProgress,
    required this.momDeltaPct,
    required this.budgetCount,
    required this.topCategoryName,
    required this.recent,
  });

  final int totalBalance;
  final int monthIncome;
  final int monthExpense;
  final int remainingBudget;
  final double? budgetProgress;
  final int momDeltaPct;
  final int budgetCount;
  final String? topCategoryName;
  final List<TransactionWithDetails> recent;
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    final settings = ref.watch(settingsProvider);
    final txRepo = ref.watch(transactionRepositoryProvider);
    final accountRepo = ref.watch(accountRepositoryProvider);
    final budgetRepo = ref.watch(budgetRepositoryProvider);

    // Refresh whenever underlying data changes.
    ref.listen(transactionStreamSignalProvider, (_, __) => ref.invalidateSelf());

    final accounts = await accountRepo.watchAllWithBalance().first;
    final totalBalance = accounts.fold<int>(0, (a, b) => a + b.balance);

    final thisMonth = TimeRange.month(DateTime.now(), monthStartDay: settings.budgetStartDay);
    final lastMonth = TimeRange.month(
        DateTime(thisMonth.start.year, thisMonth.start.month - 1, 1),
        monthStartDay: settings.budgetStartDay);

    final cur = await txRepo.watchTotalsInRange(thisMonth.start, thisMonth.end).first;
    final prev = await txRepo.watchTotalsInRange(lastMonth.start, lastMonth.end).first;

    final mom = prev.expense <= 0 ? 0 : (((cur.expense - prev.expense) / prev.expense) * 100).round();

    final budgets = await budgetRepo.watchProgress().first;
    final overall = budgets.where((b) => b.budget.categoryId == null).toList();
    final remaining = overall.isEmpty ? 0 : overall.first.remaining;
    final progress = overall.isEmpty ? null : overall.first.progress;

    final topCategory = await txRepo.watchSpendingByCategory(thisMonth.start, thisMonth.end).first;
    final topName = topCategory.isEmpty ? null : topCategory.first.categoryName;

    final recent = await txRepo.watchRecent(8).first;

    return DashboardState(
      totalBalance: totalBalance,
      monthIncome: cur.income,
      monthExpense: cur.expense,
      remainingBudget: remaining,
      budgetProgress: progress,
      momDeltaPct: mom,
      budgetCount: budgets.length,
      topCategoryName: topName,
      recent: recent,
    );
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
