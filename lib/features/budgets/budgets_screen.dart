import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/core/design_system/widgets/progress_budget_bar.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final budgets = ref.watch(budgetsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.budgets)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEdit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(l.noBudgetsYet))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (c, i) {
                  final p = list[i];
                  return Card(
                    child: InkWell(
                      onTap: () => _showEdit(context, ref, p.budget),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.categoryName ?? l.budgets,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                if (p.overBudget)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      l.overBudget,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onErrorContainer,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ProgressBudgetBar(
                              spentMinor: p.spentMinor,
                              limitMinor: p.budget.amount,
                              overBudget: p.overBudget,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.spentOf(
                                ref.read(moneyFormatterProvider).format(p.spentMinor),
                                ref.read(moneyFormatterProvider).format(p.budget.amount),
                              ),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            if (p.budget.carryOver)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• ${l.carryOver}',
                                    style: Theme.of(context).textTheme.labelSmall),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, Budget? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetEditSheet(existing: existing),
    );
  }
}

class _BudgetEditSheet extends ConsumerStatefulWidget {
  const _BudgetEditSheet({this.existing});
  final Budget? existing;
  @override
  ConsumerState<_BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends ConsumerState<_BudgetEditSheet> {
  final _amount = TextEditingController();
  int? _categoryId;
  BudgetPeriod _period = BudgetPeriod.monthly;
  bool _carry = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _amount.text = widget.existing!.amount.toString();
      _categoryId = widget.existing!.categoryId;
      _period = widget.existing!.period;
      _carry = widget.existing!.carryOver;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final money = ref.watch(moneyFormatterProvider);
    final cats = ref.watch(allExpenseCategoriesStreamProvider).valueOrNull ?? [];
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int?>(
          decoration: InputDecoration(labelText: l.category),
          value: _categoryId,
          items: [
            DropdownMenuItem(value: null, child: Text(l.allTime)),
            for (final c in cats)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.amount),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<BudgetPeriod>(
          value: _period,
          decoration: InputDecoration(labelText: l.period),
          items: const [
            DropdownMenuItem(value: BudgetPeriod.weekly, child: Text('Weekly')),
            DropdownMenuItem(value: BudgetPeriod.monthly, child: Text('Monthly')),
            DropdownMenuItem(value: BudgetPeriod.custom, child: Text('Custom')),
          ],
          onChanged: (v) => setState(() => _period = v!),
        ),
        SwitchListTile(
          title: Text(l.carryOver),
          value: _carry,
          onChanged: (v) => setState(() => _carry = v),
        ),
        FilledButton(
          onPressed: () async {
            final minor = money.parseMinor(_amount.text) ?? 0;
            final repo = ref.read(budgetRepositoryProvider);
            await repo.upsert(
              id: widget.existing?.id,
              categoryId: _categoryId,
              amountMinor: minor,
              period: _period,
              carryOver: _carry,
            );
            if (mounted) Navigator.pop(context);
          },
          child: Text(l.save),
        ),
      ]),
    );
  }
}
