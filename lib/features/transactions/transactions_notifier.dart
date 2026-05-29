import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

class TransactionsController extends Notifier<void> {
  @override
  void build() {}

  Future<List<TransactionWithDetails>> fetchPage({
    required int offset,
    required int limit,
    String query = '',
  }) =>
      ref.read(transactionRepositoryProvider).getPage(
            offset: offset,
            limit: limit,
            query: query,
          );

  Future<void> delete(int id) =>
      ref.read(transactionRepositoryProvider).delete(id);

  Future<void> duplicate(int id) =>
      ref.read(transactionRepositoryProvider).duplicate(id);
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsController, void>(TransactionsController.new);
