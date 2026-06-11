import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:expense_budget_manager/core/design_system/widgets/transaction_row.dart';
import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';
import 'package:expense_budget_manager/features/transactions/transactions_notifier.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TxScreenState();
}

class _TxScreenState extends ConsumerState<TransactionsScreen> {
  static const _pageSize = 50;
  final _pagingController = PagingController<int, TransactionWithDetails>(firstPageKey: 0);
  String _query = '';

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final notifier = ref.read(transactionsNotifierProvider.notifier);
      final items = await notifier.fetchPage(
        offset: pageKey,
        limit: _pageSize,
        query: _query,
      );
      final isLast = items.length < _pageSize;
      if (isLast) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, pageKey + items.length);
      }
    } catch (e) {
      _pagingController.error = e;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dateF = ref.watch(dateFormatterProvider);

    // Refresh when underlying tx data changes.
    ref.listen(transactionStreamSignalProvider, (_, __) {
      _pagingController.refresh();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTransactions),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() => _query = v);
                _pagingController.refresh();
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _pagingController.refresh(),
        child: PagedListView<int, TransactionWithDetails>.separated(
          pagingController: _pagingController,
          padding: const EdgeInsets.only(bottom: 120),
          separatorBuilder: (c, i) {
            final list = _pagingController.itemList;
            // i+1 can index past the end when a paging loader/error tile is
            // appended (itemCount > itemList.length) — guard against RangeError.
            if (list == null || i + 1 >= list.length) {
              return const Divider(height: 0);
            }
            final current = list[i];
            final next = list[i + 1];
            final aDay = DateTime(current.dateTime.year, current.dateTime.month, current.dateTime.day);
            final bDay = DateTime(next.dateTime.year, next.dateTime.month, next.dateTime.day);
            if (aDay == bDay) return const Divider(height: 0);
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
              child: Text(
                dateF.full(next.dateTime),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            );
          },
          builderDelegate: PagedChildBuilderDelegate<TransactionWithDetails>(
            itemBuilder: (c, item, i) => Dismissible(
              key: ValueKey(item.id),
              background: Container(color: Colors.red, alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsetsDirectional.only(end: 24),
                  child: const Icon(Icons.delete, color: Colors.white)),
              direction: DismissDirection.endToStart,
              // Bug 2 fix: do the delete here and ALWAYS return false. Returning
              // true makes Dismissible finalize its own removal, but the paged
              // list still holds the item until the async delete + stream
              // refresh completes — so the dismissed widget lingers in the tree
              // and trips the "dismissed Dismissible is still part of the tree"
              // assertion, which black-screens / freezes the list. By returning
              // false, the row is never removed by Dismissible; it disappears
              // when transactionStreamSignalProvider refreshes the controller
              // after the DB delete commits. No assertion, no black screen.
              confirmDismiss: (_) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(l.confirmDelete),
                    content: Text(l.deleteIrreversible),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
                      FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
                    ],
                  ),
                ) ?? false;
                if (confirmed) {
                  await ref
                      .read(transactionsNotifierProvider.notifier)
                      .delete(item.id);
                }
                return false;
              },
              child: InkWell(
                onTap: () => context.push('${AppRoutes.addEdit}?txId=${item.id}'),
                onLongPress: () {
                  ref.read(transactionsNotifierProvider.notifier).duplicate(item.id);
                },
                child: TransactionRow(detail: item),
              ),
            ),
            noItemsFoundIndicatorBuilder: (_) => Center(child: Text(l.noTransactionsYet)),
          ),
        ),
      ),
    );
  }
}
