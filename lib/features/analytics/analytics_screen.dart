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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navAnalytics),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l.exportCsv,
            onPressed: () => ref.read(analyticsNotifierProvider.notifier).exportCsv(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PeriodSelector(
              value: s.period,
              onChanged: (p) =>
                  ref.read(analyticsNotifierProvider.notifier).setPeriod(p),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: l.expense),
            SizedBox(
              height: 220,
              child: s.byCategory.isEmpty
                  ? Center(child: Text(l.noTransactionsYet))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 48,
                        sections: [
                          for (final e in s.byCategory)
                            PieChartSectionData(
                              value: e.totalMinor.toDouble(),
                              title: e.categoryName,
                              color: e.color,
                              radius: 60,
                              titleStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: l.monthlySpending),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < s.trend.length; i++)
                          FlSpot(i.toDouble(), s.trend[i].totalMinor.toDouble()),
                      ],
                      isCurved: true,
                      color: scheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
