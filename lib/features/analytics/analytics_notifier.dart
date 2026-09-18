import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense_budget_manager/core/common/amount_codec.dart';
import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';
import 'package:expense_budget_manager/domain/repository/transaction_repository.dart';
import 'package:expense_budget_manager/features/analytics/analytics_math.dart';

enum AnalyticsPeriod {
  day,
  week,
  month,
  specificMonth,
  quarter,
  year,
  custom,
  all,
}

enum AnalyticsChartType { pie, doughnut, bar, horizontalBar, line, area }

class AnalyticsState {
  const AnalyticsState({
    required this.period,
    required this.chartType,
    required this.grouping,
    required this.accountId,
    required this.categoryId,
    required this.customStart,
    required this.customEnd,
    required this.selectedMonth,
    required this.range,
    required this.byCategory,
    required this.trend,
    required this.totalExpense,
    required this.totalIncome,
    required this.topCategory,
  });
  final AnalyticsPeriod period;
  final AnalyticsChartType chartType;
  final CategoryGrouping grouping;
  final int? accountId; // null = all accounts
  final int? categoryId; // null = all; may be a parent or a subcategory
  final DateTime? customStart;
  final DateTime? customEnd;
  final DateTime? selectedMonth; // first day of the chosen month
  /// The range actually in effect, so the screen can show it.
  final TimeRange range;
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
  CategoryGrouping _grouping = CategoryGrouping.parent;
  int? _accountId;
  int? _categoryId;
  DateTime? _customStart;
  DateTime? _customEnd;
  DateTime? _selectedMonth;

  @override
  Future<AnalyticsState> build() async {
    ref.listen(transactionStreamSignalProvider, (_, __) => ref.invalidateSelf());
    final s = ref.watch(settingsProvider);
    final txRepo = ref.watch(transactionRepositoryProvider);
    final categories = await ref.watch(allCategoriesStreamProvider.future);
    final range = _rangeFor(_period, s.weekStartDay, s.budgetStartDay);

    final all = await txRepo.getPage(offset: 0, limit: 100000);
    final inScope = _inScope(all, range, categories);

    var totalExpense = 0;
    var totalIncome = 0;
    for (final t in inScope) {
      if (t.type == TransactionType.expense) totalExpense += t.amountMinor;
      if (t.type == TransactionType.income) totalIncome += t.amountMinor;
    }

    final slices = buildCategoryBreakdown(
      transactions: inScope,
      categories: categories,
      grouping: _grouping,
      // The screen localises direct-on-parent slices; keep the bare name here.
      directOnParentLabel: (name) => name,
    );

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
      grouping: _grouping,
      accountId: _accountId,
      categoryId: _categoryId,
      customStart: _customStart,
      customEnd: _customEnd,
      selectedMonth: _selectedMonth,
      range: range,
      byCategory: slices,
      trend: trend,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      topCategory: slices.isEmpty ? null : slices.first.name,
    );
  }

  /// Date range + account + category filtering, shared by the charts and the
  /// CSV export so the file always matches what is on screen.
  List<TransactionWithDetails> _inScope(
    List<TransactionWithDetails> all,
    TimeRange range,
    List<Category> categories,
  ) {
    final parentOf = parentIndex(categories);
    return all.where((t) {
      if (!range.contains(t.dateTime)) return false;
      if (_accountId != null && t.accountId != _accountId) return false;
      return categoryMatchesFilter(
        txCategoryId: t.categoryId,
        filterId: _categoryId,
        parentOf: parentOf,
      );
    }).toList();
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
      case AnalyticsPeriod.specificMonth:
        final m = _selectedMonth ?? DateTime(now.year, now.month);
        return specificMonthRange(
          year: m.year,
          month: m.month,
          monthStartDay: budgetStartDay,
        );
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

  /// Report on one specific month, e.g. March 2026.
  void setSpecificMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    _period = AnalyticsPeriod.specificMonth;
    ref.invalidateSelf();
  }

  void setChartType(AnalyticsChartType t) {
    _chartType = t;
    ref.invalidateSelf();
  }

  void setGrouping(CategoryGrouping g) {
    _grouping = g;
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
    final categories = await ref.read(allCategoriesStreamProvider.future);
    final range = _rangeFor(_period, s.weekStartDay, s.budgetStartDay);

    final all = await txRepo.getPage(offset: 0, limit: 100000);
    // The export mirrors the on-screen filters, not just the date range.
    final inScope = _inScope(all, range, categories);

    final byId = {for (final c in categories) c.id: c};
    final rows = <List<dynamic>>[
      [
        'id',
        'date',
        'type',
        'category',
        'subcategory',
        'account',
        'amount',
        'note',
      ],
      ...inScope.map((t) {
        final category = t.categoryId == null ? null : byId[t.categoryId];
        final parent =
            category?.parentId == null ? category : byId[category!.parentId];
        return [
          t.id,
          t.dateTime.toIso8601String(),
          t.type.name,
          parent?.name ?? t.categoryName ?? '',
          // Empty when the transaction sits directly on a top-level category.
          category != null && category.parentId != null ? category.name : '',
          t.accountName,
          // Locale-independent fixed-point string ("55.00"), not raw minor
          // units ("5500") — Bug 4. Import mirrors this via AmountCodec.decode.
          AmountCodec.encode(t.amountMinor),
          t.note ?? '',
        ];
      }),
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
