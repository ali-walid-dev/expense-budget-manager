import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/repository/transaction_repository.dart';

enum AnalyticsPeriod { day, week, month, quarter, year, all }

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
    required this.byCategory,
    required this.trend,
    required this.totalExpense,
    required this.totalIncome,
    required this.topCategory,
  });
  final AnalyticsPeriod period;
  final List<CategorySlice> byCategory;
  final List<DailySpend> trend;
  final int totalExpense;
  final int totalIncome;
  final String? topCategory;

  AnalyticsState copyWith({AnalyticsPeriod? period}) => AnalyticsState(
        period: period ?? this.period,
        byCategory: byCategory,
        trend: trend,
        totalExpense: totalExpense,
        totalIncome: totalIncome,
        topCategory: topCategory,
      );
}

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;

  @override
  Future<AnalyticsState> build() async {
    ref.listen(transactionStreamSignalProvider, (_, __) => ref.invalidateSelf());
    final s = ref.watch(settingsProvider);
    final txRepo = ref.watch(transactionRepositoryProvider);
    final range = _rangeFor(_period, s.weekStartDay, s.budgetStartDay);

    final byCat = await txRepo.watchSpendingByCategory(range.start, range.end).first;
    final trend = await txRepo.watchDailyTrend(range.start, range.end).first;
    final totals = await txRepo.watchTotalsInRange(range.start, range.end).first;

    return AnalyticsState(
      period: _period,
      byCategory: byCat
          .map((e) => CategorySlice(
                categoryName: e.categoryName,
                totalMinor: e.totalMinor,
                color: hexToColor(e.colorHex),
              ))
          .toList(),
      trend: trend,
      totalExpense: totals.expense,
      totalIncome: totals.income,
      topCategory: byCat.isEmpty ? null : byCat.first.categoryName,
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
      case AnalyticsPeriod.all:
        return TimeRange(DateTime(1970), DateTime(now.year + 1, 1, 1));
    }
  }

  Future<void> setPeriod(AnalyticsPeriod p) async {
    _period = p;
    ref.invalidateSelf();
  }

  Future<void> exportCsv() async {
    final txRepo = ref.read(transactionRepositoryProvider);
    final s = ref.read(settingsProvider);
    final range = _rangeFor(_period, s.weekStartDay, s.budgetStartDay);
    final all = await txRepo.getPage(offset: 0, limit: 100000);
    final inRange = all.where((t) =>
        t.dateTime.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
        t.dateTime.isBefore(range.end));

    final rows = <List<dynamic>>[
      ['id', 'date', 'type', 'category', 'account', 'amount', 'note'],
      ...inRange.map((t) => [
            t.id,
            t.dateTime.toIso8601String(),
            t.type.name,
            t.categoryName ?? '',
            t.accountName,
            t.amountMinor,
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
