import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/core/design_system/widgets/section_header.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/features/analytics/analytics_notifier.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(analyticsNotifierProvider);
    final money = ref.watch(moneyFormatterProvider);
    final notifier = ref.read(analyticsNotifierProvider.notifier);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final parents = (ref.watch(categoryTreeStreamProvider).valueOrNull ?? [])
        .map((n) => n.category)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navAnalytics),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l.exportCsv,
            onPressed: () => notifier.exportCsv(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ChartTypeSelector(
              value: s.chartType,
              onChanged: notifier.setChartType,
            ),
            const SizedBox(height: 12),
            _PeriodSelector(
              value: s.period,
              onChanged: (p) async {
                if (p == AnalyticsPeriod.custom) {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(now.year + 1),
                    initialDateRange: DateTimeRange(
                      start: s.customStart ?? DateTime(now.year, now.month, 1),
                      end: s.customEnd ?? now,
                    ),
                  );
                  if (picked != null) {
                    notifier.setCustomRange(picked.start, picked.end);
                  }
                } else {
                  notifier.setPeriod(p);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: l.account, isDense: true),
                    value: s.accountId,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.allAccounts)),
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: notifier.setAccount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: l.category, isDense: true),
                    value: s.categoryId,
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l.allCategories)),
                      for (final c in parents)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: notifier.setCategory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(title: l.expense),
            SizedBox(height: 260, child: _Chart(state: s)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.topCategory != null)
                      Text(l.highestCategory(s.topCategory!)),
                    const SizedBox(height: 4),
                    Text('${l.expense}: ${money.format(s.totalExpense)}'),
                    Text('${l.income}: ${money.format(s.totalIncome)}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders whichever chart the user selected, with a shared empty state.
class _Chart extends StatelessWidget {
  const _Chart({required this.state});
  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasCategoryData = state.byCategory.isNotEmpty;
    final hasTrendData = state.trend.isNotEmpty;

    switch (state.chartType) {
      case AnalyticsChartType.pie:
      case AnalyticsChartType.doughnut:
        if (!hasCategoryData) return _empty(context, l);
        return PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius:
              state.chartType == AnalyticsChartType.doughnut ? 64 : 0,
          sections: [
            for (final e in state.byCategory)
              PieChartSectionData(
                value: e.totalMinor.toDouble(),
                title: e.categoryName,
                color: e.color,
                radius: 80,
                titleStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              ),
          ],
        ));

      case AnalyticsChartType.bar:
        if (!hasCategoryData) return _empty(context, l);
        final maxY = state.byCategory
            .map((e) => e.totalMinor)
            .fold<int>(0, (a, b) => a > b ? a : b)
            .toDouble();
        return BarChart(BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= state.byCategory.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(state.byCategory[i].categoryName,
                        style: const TextStyle(fontSize: 9),
                        overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < state.byCategory.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: state.byCategory[i].totalMinor.toDouble(),
                  color: state.byCategory[i].color,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
          ],
        ));

      case AnalyticsChartType.horizontalBar:
        if (!hasCategoryData) return _empty(context, l);
        // fl_chart has no native horizontal bar; render proportional rows.
        final maxV = state.byCategory
            .map((e) => e.totalMinor)
            .fold<int>(1, (a, b) => a > b ? a : b);
        return ListView(
          children: [
            for (final e in state.byCategory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(e.categoryName,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.totalMinor / maxV,
                          minHeight: 16,
                          backgroundColor: e.color.withOpacity(0.15),
                          color: e.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case AnalyticsChartType.line:
      case AnalyticsChartType.area:
        if (!hasTrendData) return _empty(context, l);
        final isArea = state.chartType == AnalyticsChartType.area;
        return LineChart(LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < state.trend.length; i++)
                  FlSpot(i.toDouble(), state.trend[i].totalMinor.toDouble()),
              ],
              isCurved: true,
              color: scheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: isArea,
                color: scheme.primary.withOpacity(0.20),
              ),
            ),
          ],
        ));
    }
  }

  Widget _empty(BuildContext context, AppLocalizations l) =>
      Center(child: Text(l.noData));
}

class _ChartTypeSelector extends StatelessWidget {
  const _ChartTypeSelector({required this.value, required this.onChanged});
  final AnalyticsChartType value;
  final ValueChanged<AnalyticsChartType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = <AnalyticsChartType, String>{
      AnalyticsChartType.pie: l.chartPie,
      AnalyticsChartType.doughnut: l.chartDoughnut,
      AnalyticsChartType.bar: l.chartBar,
      AnalyticsChartType.horizontalBar: l.chartHorizontalBar,
      AnalyticsChartType.line: l.chartLine,
      AnalyticsChartType.area: l.chartArea,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in AnalyticsChartType.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(labels[t]!),
                selected: t == value,
                onSelected: (_) => onChanged(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});
  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = <AnalyticsPeriod, String>{
      AnalyticsPeriod.day: l.day,
      AnalyticsPeriod.week: l.week,
      AnalyticsPeriod.month: l.month,
      AnalyticsPeriod.quarter: l.quarter,
      AnalyticsPeriod.year: l.year,
      AnalyticsPeriod.custom: l.customRange,
      AnalyticsPeriod.all: l.allTime,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in AnalyticsPeriod.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(labels[p]!),
                selected: p == value,
                onSelected: (_) => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }
}
