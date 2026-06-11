import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense_budget_manager/core/common/amount_codec.dart';
import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/repository/transaction_repository.dart';

enum AnalyticsPeriod { day, week, month, quarter, year, custom, all }

enum AnalyticsChartType { pie, doughnut, bar, horizontalBar, line, area }

class CategorySlice {
  const CategorySlice({
    required this.categoryName,
    required this.totalMinor,
    required this.color,
  });
  final String categoryName;
  final int totalMinor;
  final Color color;
}

class AnalyticsState {
  const AnalyticsState({
    required this.period,
    required this.chartType,
    required this.accountId,
    required this.categoryId,
    required this.customStart,
    required this.customEnd,
    required this.byCategory,
    required this.trend,
    required this.totalExpense,
    required this.totalIncome,
    required this.topCategory,
  });
  final AnalyticsPeriod period;
  final AnalyticsChartType chartType;
  final int? accountId; // null = all accounts
  final int? categoryId; // null = all parent categories
  final DateTime? customStart;
  final DateTime? customEnd;
  final List<CategorySlice> byCategory;
  final List<DailySpend> trend;
  final int totalExpense;
  final int totalIncome;
  final String? topCategory;

  bool get isCategoryChart =>
      chartType == AnalyticsChartType.pie ||
      chartType == AnalyticsChartType.doughnut ||
      chartType == AnalyticsChartType.bar ||
      chartType == AnalyticsChartType.horizontalBar;
}

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  AnalyticsChartType _chartType = AnalyticsChartType.pie;
  int? _accountId;
  int? _categoryId;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  Future<AnalyticsState> build() async {
    ref.listen(transactionStreamSignalProvider, (_, __) => ref.invalidateSelf());
    final s = ref.watch(settingsProvider);
    final txRepo = ref.watch(transactionRepositoryProvider);
    final categories = await ref.watch(allCategoriesStreamProvider.future);
    final range = _rangeFor(_period, s.weekStartDay, s.budgetStartDay);

    final all = await txRepo.getPage(offset: 0, limit: 100000);

    // Map every category to its top-level parent for roll-up + filtering.
    final parentOf = <int, int>{
      for (final c in categories) c.id: c.parentId ?? c.id,
    };
    final parentInfo = <int, Category>{
      for (final c in categories.where((c) => c.parentId == null)) c.id: c,
    };

    final inScope = all.where((t) {
      if (t.dateTime.isBefore(range.start) || !t.dateTime.isBefore(range.end)) {
        return false;
      }
      if (_accountId != null && t.accountId != _accountId) return false;
      if (_categoryId != null) {
        final parent = t.categoryId == null ? null : parentOf[t.categoryId];
        if (parent != _categoryId) return false;
      }
      return true;
    }).toList();

    // Totals.
    var totalExpense = 0;
    var totalIncome = 0;
    for (final t in inScope) {
      if (t.type == TransactionType.expense) totalExpense += t.amountMinor;
      if (t.type == TransactionType.income) totalIncome += t.amountMinor;
    }

    // Spend by parent category (expense only), descending.
    final byParent = <int, int>{};
    for (final t in inScope.where((t) => t.type == TransactionType.expense)) {
      if (t.categoryId == null) continue;
      final parent = parentOf[t.categoryId] ?? t.categoryId!;
      byParent[parent] = (byParent[parent] ?? 0) + t.amountMinor;
    }
    final slices = byParent.entries
        .map((e) => CategorySlice(
              categoryName: parentInfo[e.key]?.name ?? '—',
              totalMinor: e.value,
              color: parentInfo[e.key]?.color ?? Colors.grey,
            ))
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));

    // Daily expense trend.
    final byDay = <int, int>{};
    for (final t in inScope.where((t) => t.type == TransactionType.expense)) {
      final day = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day)
          .millisecondsSinceEpoch;
      byDay[day] = (byDay[day] ?? 0) + t.amountMinor;
    }
    final trend = (byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => DailySpend(
              day: DateTime.fromMillisecondsSinceEpoch(e.key),
              totalMinor: e.value,
            ))
        .toList();

    return AnalyticsState(
      period: _period,
      chartType: _chartType,
      accountId: _accountId,
      categoryId: _categoryId,
      customStart: _customStart,
      customEnd: _customEnd,
      byCategory: slices,
      trend: trend,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      topCategory: slices.isEmpty ? null : slices.first.categoryName,
    );
  }

  TimeRange _rangeFor(AnalyticsPeriod p, int weekStartDay, int budgetStartDay) {
    final now = DateTime.now();
    switch (p) {
      case AnalyticsPeriod.day:
        return TimeRange.day(now);
      case AnalyticsPeriod.week:
        return TimeRange.week(now, weekStartDay: weekStartDay);
      case AnalyticsPeriod.month:
        return TimeRange.month(now, monthStartDay: budgetStartDay);
      case AnalyticsPeriod.quarter:
        final s = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
        return TimeRange(s, DateTime(s.year, s.month + 3, 1));
      case AnalyticsPeriod.year:
        return TimeRange.year(now);
      case AnalyticsPeriod.custom:
        final start = _customStart ?? DateTime(now.year, now.month, 1);
        final endExclusive = (_customEnd ?? now).add(const Duration(days: 1));
        return TimeRange(
          DateTime(start.year, start.month, start.day),
          DateTime(endExclusive.year, endExclusive.month, endExclusive.day),
        );
      case AnalyticsPeriod.all:
        return TimeRange(DateTime(1970), DateTime(now.year + 1, 1, 1));
    }
  }

  void setPeriod(AnalyticsPeriod p) {
    _period = p;
    ref.invalidateSelf();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _customStart = start;
    _customEnd = end;
    _period = AnalyticsPeriod.custom;
    ref.invalidateSelf();
  }

  void setChartType(AnalyticsChartType t) {
    _chartType = t;
    ref.invalidateSelf();
  }

  void setAccount(int? id) {
    _accountId = id;
    ref.invalidateSelf();
  }

  void setCategory(int? id) {
    _categoryId = id;
    ref.invalidateSelf();
  }

  Future<void> exportCsv() async {
    final txRepo = ref.read(transactionRepositoryProvider);
    final s = ref.read(settingsProvider);
    final range = _rangeFor(_period, s.weekStartDay, s.budgetStartDay);
    final all = await txRepo.getPage(offset: 0, limit: 100000);
    final inRange = all.where((t) =>
        !t.dateTime.isBefore(range.start) && t.dateTime.isBefore(range.end));

    final rows = <List<dynamic>>[
      ['id', 'date', 'type', 'category', 'account', 'amount', 'note'],
      ...inRange.map((t) => [
            t.id,
            t.dateTime.toIso8601String(),
            t.type.name,
            t.categoryName ?? '',
            t.accountName,
            // Locale-independent fixed-point string ("55.00"), not raw minor
            // units ("5500") — Bug 4. Import mirrors this via AmountCodec.decode.
            AmountCodec.encode(t.amountMinor),
            t.note ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path,
        'expenses_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], subject: 'Expenses export');
  }
}

final analyticsNotifierProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);
