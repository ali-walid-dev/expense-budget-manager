import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/core/common/amount_codec.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/debt.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final debts = ref.watch(debtsStreamProvider);
    final money = ref.watch(moneyFormatterProvider);
    final dateF = ref.watch(dateFormatterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.debts)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEdit(context, null),
        child: const Icon(Icons.add),
      ),
      body: debts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(l.noDebtsYet))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (c, i) {
                  final p = list[i];
                  return Card(
                    child: InkWell(
                      onTap: () => _showEdit(context, p.debt),
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
                                    p.debt.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                _StatusChip(completed: p.isCompleted),
                              ],
                            ),
                            if (p.debt.creditor != null &&
                                p.debt.creditor!.isNotEmpty)
                              Text(p.debt.creditor!,
                                  style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: p.progress),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _Metric(label: l.total, value: money.format(p.debt.totalAmount)),
                                _Metric(label: l.paid, value: money.format(p.paidMinor)),
                                _Metric(label: l.remaining, value: money.format(p.remainingMinor)),
                              ],
                            ),
                            if (p.nextPaymentDate != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${l.nextPayment}: ${dateF.full(p.nextPaymentDate!)}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
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

  void _showEdit(BuildContext context, Debt? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DebtEditSheet(existing: existing),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.completed});
  final bool completed;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: completed ? scheme.primaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        completed ? l.statusCompleted : l.statusActive,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DebtEditSheet extends ConsumerStatefulWidget {
  const _DebtEditSheet({this.existing});
  final Debt? existing;
  @override
  ConsumerState<_DebtEditSheet> createState() => _DebtEditSheetState();
}

class _DebtEditSheetState extends ConsumerState<_DebtEditSheet> {
  final _name = TextEditingController();
  final _creditor = TextEditingController();
  final _total = TextEditingController();
  final _monthly = TextEditingController();
  final _note = TextEditingController();
  int? _accountId;
  int? _categoryId;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _creditor.text = e.creditor ?? '';
      _total.text = AmountCodec.encode(e.totalAmount);
      _monthly.text = AmountCodec.encode(e.monthlyPayment);
      _note.text = e.note ?? '';
      _accountId = e.accountId;
      _categoryId = e.categoryId;
      _startDate = e.startDate;
      _dueDate = e.dueDate;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _creditor.dispose();
    _total.dispose();
    _monthly.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final money = ref.watch(moneyFormatterProvider);
    final dateF = ref.watch(dateFormatterProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final cats = ref.watch(allExpenseCategoriesStreamProvider).valueOrNull ?? [];
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.name),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _creditor,
            decoration: InputDecoration(labelText: l.creditor),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.totalAmount),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _monthly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.monthlyPayment),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            decoration: InputDecoration(labelText: l.account),
            value: _accountId,
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            decoration: InputDecoration(labelText: l.category),
            value: _categoryId,
            items: [
              DropdownMenuItem(value: null, child: Text('—')),
              for (final c in cats)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l.startDate),
            subtitle: Text(dateF.full(_startDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available),
            title: Text(l.dueDate),
            subtitle: Text(_dueDate == null ? '—' : dateF.full(_dueDate!)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l.note),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (isEditing)
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.delete),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                final total = money.parseMinor(_total.text) ?? 0;
                final monthly = money.parseMinor(_monthly.text) ?? 0;
                if (_name.text.trim().isEmpty ||
                    total <= 0 ||
                    monthly <= 0 ||
                    _accountId == null) {
                  return;
                }
                final repo = ref.read(debtRepositoryProvider);
                await repo.upsert(
                  id: widget.existing?.id,
                  name: _name.text.trim(),
                  creditor:
                      _creditor.text.trim().isEmpty ? null : _creditor.text.trim(),
                  totalAmountMinor: total,
                  monthlyPaymentMinor: monthly,
                  startDate: _startDate,
                  dueDate: _dueDate,
                  note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  accountId: _accountId!,
                  categoryId: _categoryId,
                );
                // Generate any payments already due (catch-up) so the dashboard
                // is correct immediately.
                await repo.runDueDebts();
                if (mounted) Navigator.pop(context);
              },
              child: Text(l.save),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.deleteDebt),
        content: Text(l.deleteIrreversible),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(debtRepositoryProvider).delete(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
