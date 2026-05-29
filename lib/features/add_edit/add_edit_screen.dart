import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/features/add_edit/add_edit_notifier.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class AddEditScreen extends ConsumerStatefulWidget {
  const AddEditScreen({super.key, this.transactionId});
  final int? transactionId;
  @override
  ConsumerState<AddEditScreen> createState() => _AddEditState();
}

class _AddEditState extends ConsumerState<AddEditScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addEditNotifierProvider(widget.transactionId).notifier).init();
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(addEditNotifierProvider(widget.transactionId));
    final notifier = ref.read(addEditNotifierProvider(widget.transactionId).notifier);
    final money = ref.watch(moneyFormatterProvider);
    final dateF = ref.watch(dateFormatterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId == null ? l.addTransaction : l.editTransaction),
        actions: [
          if (widget.transactionId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(l.confirmDelete),
                    content: Text(l.deleteIrreversible),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
                      FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
                    ],
                  ),
                );
                if (ok == true) {
                  await notifier.delete();
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Big amount
              TextField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixText: ref.read(settingsProvider).currency,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]')),
                ],
                onChanged: (v) {
                  final minor = money.parseMinor(v);
                  if (minor != null) notifier.setAmount(minor);
                },
              ),
              const SizedBox(height: 12),
              // Type selector
              SegmentedButton<TransactionType>(
                segments: [
                  ButtonSegment(value: TransactionType.expense, label: Text(l.typeExpense)),
                  ButtonSegment(value: TransactionType.income, label: Text(l.typeIncome)),
                  ButtonSegment(value: TransactionType.transfer, label: Text(l.typeTransfer)),
                ],
                selected: {s.type},
                onSelectionChanged: (sel) => notifier.setType(sel.first),
              ),
              const SizedBox(height: 16),
              if (s.type != TransactionType.transfer) ...[
                Text(l.category, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: s.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (c, i) {
                      final cat = s.categories[i];
                      final selected = cat.id == s.categoryId;
                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: selected,
                        onSelected: (_) => notifier.setCategory(cat.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Account
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                    labelText: s.type == TransactionType.transfer ? l.accountFrom : l.account),
                value: s.accountId,
                items: [
                  for (final a in s.accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => notifier.setAccount(v),
              ),
              if (s.type == TransactionType.transfer) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: l.accountTo),
                  value: s.toAccountId,
                  items: [
                    for (final a in s.accounts)
                      if (a.id != s.accountId)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => notifier.setToAccount(v),
                ),
              ],
              const SizedBox(height: 16),
              // More
              InkWell(
                onTap: () => setState(() => _showMore = !_showMore),
                child: Row(
                  children: [
                    Text(_showMore ? l.less : l.more),
                    Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
              if (_showMore) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(dateF.full(s.dateTime)),
                  subtitle: Text(dateF.time(s.dateTime)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: s.dateTime,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) notifier.setDate(picked);
                  },
                ),
                TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(labelText: l.note),
                  onChanged: notifier.setNote,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(l.recurring),
                  value: s.recurring,
                  onChanged: notifier.setRecurring,
                ),
                if (s.recurring)
                  DropdownButtonFormField<RecurringInterval>(
                    decoration: InputDecoration(labelText: l.recurring),
                    value: s.recurringInterval,
                    items: [
                      for (final r in RecurringInterval.values)
                        DropdownMenuItem(value: r, child: Text(_intervalLabel(l, r))),
                    ],
                    onChanged: (v) => notifier.setRecurringInterval(v!),
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: s.canSave
                    ? () async {
                        await notifier.save();
                        if (context.mounted) context.pop();
                      }
                    : null,
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
  }

  String _intervalLabel(AppLocalizations l, RecurringInterval r) => switch (r) {
        RecurringInterval.daily => l.intervalDaily,
        RecurringInterval.weekly => l.intervalWeekly,
        RecurringInterval.monthly => l.intervalMonthly,
        RecurringInterval.yearly => l.intervalYearly,
      };
}
