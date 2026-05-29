import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/design_system/widgets/transaction_row.dart';
import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final results = ref.watch(searchStreamProvider(_q));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.search,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
      ),
      body: _q.isEmpty
          ? Center(child: Text(l.search))
          : results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => list.isEmpty
                  ? Center(child: Text(l.noTransactionsYet))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final tx = list[i];
                        return InkWell(
                          onTap: () =>
                              context.push('${AppRoutes.addEdit}?txId=${tx.id}'),
                          child: TransactionRow(detail: tx),
                        );
                      },
                    ),
            ),
    );
  }
}
