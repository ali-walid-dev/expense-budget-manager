import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/design_system/app_theme.dart';
import 'package:expense_budget_manager/core/design_system/widgets/money_text.dart';
import 'package:expense_budget_manager/core/design_system/widgets/section_header.dart';
import 'package:expense_budget_manager/core/design_system/widgets/summary_card.dart';
import 'package:expense_budget_manager/core/design_system/widgets/transaction_row.dart';
import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/features/dashboard/dashboard_notifier.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(dashboardNotifierProvider);
    final money = ref.watch(moneyFormatterProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (s) {
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120),
          children: [
            _GreetingHeader(balance: s.totalBalance),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    label: l.income,
                    value: money.format(s.monthIncome),
                    color: AppTheme.incomeColor(context),
                    icon: Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Pill(
                    label: l.expense,
                    value: money.format(s.monthExpense),
                    color: AppTheme.expenseColor(context),
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                SummaryCard(
                  title: l.remainingBudget,
                  value: money.format(s.remainingBudget),
                  progress: s.budgetProgress,
                ),
                SummaryCard(
                  title: l.monthlySpending,
                  value: money.format(s.monthExpense),
                  delta: s.momDeltaPct,
                  deltaSuffix: l.monthOverMonth,
                ),
                SummaryCard(
                  title: l.savings,
                  value: money.format(s.monthIncome - s.monthExpense),
                ),
                SummaryCard(
                  title: l.budgets,
                  value: '${s.budgetCount}',
                  onTap: () => context.push(AppRoutes.budgets),
                ),
              ],
            ),
            if (s.topCategoryName != null) ...[
              const SizedBox(height: 16),
              _InsightBanner(text: l.highestCategory(s.topCategoryName!)),
            ],
            const SizedBox(height: 24),
            SectionHeader(
              title: l.recentTransactions,
              actionLabel: l.seeAll,
              onAction: () => context.go(AppRoutes.transactions),
            ),
            const SizedBox(height: 8),
            if (s.recent.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l.noTransactionsYet)),
              )
            else
              ...s.recent.map((tx) => TransactionRow(detail: tx)),
          ],
        );
      },
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.balance});
  final int balance;

  String _greeting(AppLocalizations l) {
    final h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning;
    if (h < 18) return l.greetingAfternoon;
    return l.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_greeting(l),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  )),
          const SizedBox(height: 8),
          Text(l.currentBalance,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withOpacity(0.7),
                  )),
          const SizedBox(height: 4),
          MoneyText(
            minorUnits: balance,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label, value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onTertiaryContainer,
                    )),
          ),
        ],
      ),
    );
  }
}
