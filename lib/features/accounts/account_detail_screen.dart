import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/design_system/widgets/money_text.dart';
import 'package:expense_budget_manager/core/design_system/widgets/transaction_row.dart';
import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final detail = ref.watch(accountDetailStreamProvider(accountId));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.account.name ?? l.account)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.balance,
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    MoneyText(
                      minorUnits: d.balance,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...d.transactions.map((tx) => InkWell(
                  onTap: () =>
                      context.push('${AppRoutes.addEdit}?txId=${tx.id}'),
                  child: TransactionRow(detail: tx),
                )),
          ],
        ),
      ),
    );
  }
}
