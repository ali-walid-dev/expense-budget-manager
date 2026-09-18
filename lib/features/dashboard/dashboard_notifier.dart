import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

class CategoryBreakdownItem {
  const CategoryBreakdownItem({
    required this.name,
    required this.totalMinor,
    required this.fraction,
    required this.color,
  });
  final String name;
  final int totalMinor;
  final double fraction; // 0..1 share of categorized monthly spend
  final Color color;
}

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
    required this.breakdown,
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
  final List<CategoryBreakdownItem> breakdown;
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

    // Monthly breakdown by parent category (children rolled up), descending.
    final byParent = await txRepo
        .watchSpendingByParentCategory(thisMonth.start, thisMonth.end)
        .first;
    final breakdownTotal = byParent.fold<int>(0, (a, b) => a + b.totalMinor);
    final breakdown = byParent
        .map((e) => CategoryBreakdownItem(
              name: e.categoryName,
              totalMinor: e.totalMinor,
              fraction:
                  breakdownTotal <= 0 ? 0 : e.totalMinor / breakdownTotal,
              color: hexToColor(e.colorHex),
            ))
        .toList();
    final topName = byParent.isEmpty ? null : byParent.first.categoryName;

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
      breakdown: breakdown,
      recent: recent,
    );
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
