import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/design_system/widgets/money_text.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsWithBalanceStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.accounts),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l.transferBetweenAccounts,
            onPressed: () => _showTransfer(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEdit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (c, i) {
            final a = list[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: a.account.color,
                  child: Icon(_iconFor(a.account.type), color: Colors.white),
                ),
                title: Text(a.account.name),
                subtitle: Text(a.account.type.name),
                trailing: MoneyText(
                  minorUnits: a.balance,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                onTap: () => context.push('/accounts/${a.account.id}'),
                onLongPress: () => _showEdit(context, ref, a.account),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(AccountType t) => switch (t) {
        AccountType.cash => Icons.payments,
        AccountType.bank => Icons.account_balance,
        AccountType.creditCard => Icons.credit_card,
        AccountType.wallet => Icons.account_balance_wallet,
        AccountType.vodafoneCash => Icons.phone_iphone,
        AccountType.instapay => Icons.bolt,
      };

  void _showEdit(BuildContext context, WidgetRef ref, Account? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountEditSheet(existing: existing),
    );
  }

  void _showTransfer(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TransferSheet(),
    );
  }
}

class _AccountEditSheet extends ConsumerStatefulWidget {
  const _AccountEditSheet({this.existing});
  final Account? existing;
  @override
  ConsumerState<_AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends ConsumerState<_AccountEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late AccountType _type;
  Color _color = const Color(0xFF16B981);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _balance = TextEditingController(text: widget.existing?.initialBalance.toString() ?? '0');
    _type = widget.existing?.type ?? AccountType.cash;
    _color = widget.existing?.color ?? const Color(0xFF16B981);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final money = ref.watch(moneyFormatterProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: l.account)),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            value: _type,
            items: [
              for (final t in AccountType.values)
                DropdownMenuItem(value: t, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() => _type = v!),
            decoration: InputDecoration(labelText: l.type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.balance),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final minor = money.parseMinor(_balance.text) ?? 0;
              final repo = ref.read(accountRepositoryProvider);
              await repo.upsert(
                id: widget.existing?.id,
                name: _name.text.trim(),
                type: _type,
                initialBalance: minor,
                color: _color,
              );
              if (mounted) Navigator.pop(context);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet();
  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amount = TextEditingController();
  int? _from;
  int? _to;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final money = ref.watch(moneyFormatterProvider);
    final accounts = ref.watch(accountsWithBalanceStreamProvider).valueOrNull ?? [];
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.transferBetweenAccounts, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(labelText: l.accountFrom),
          value: _from,
          items: [for (final a in accounts) DropdownMenuItem(value: a.account.id, child: Text(a.account.name))],
          onChanged: (v) => setState(() => _from = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(labelText: l.accountTo),
          value: _to,
          items: [
            for (final a in accounts)
              if (a.account.id != _from)
                DropdownMenuItem(value: a.account.id, child: Text(a.account.name)),
          ],
          onChanged: (v) => setState(() => _to = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.amount),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (_from != null && _to != null && _from != _to)
              ? () async {
                  final minor = money.parseMinor(_amount.text);
                  if (minor == null || minor <= 0) return;
                  await ref.read(accountRepositoryProvider).transfer(
                        fromAccountId: _from!,
                        toAccountId: _to!,
                        amountMinor: minor,
                      );
                  if (mounted) Navigator.pop(context);
                }
              : null,
          child: Text(l.save),
        ),
      ]),
    );
  }
}
