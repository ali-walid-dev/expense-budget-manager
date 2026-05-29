import 'package:flutter/material.dart';

import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

abstract class AccountRepository {
  Stream<List<Account>> watchAll();
  Stream<List<AccountWithBalance>> watchAllWithBalance();
  Stream<AccountWithBalanceAndTransactions?> watchOneDetail(int id);

  Future<int> upsert({
    int? id,
    required String name,
    required AccountType type,
    required int initialBalance,
    required Color color,
    String currency = 'EGP',
  });

  Future<void> delete(int id);

  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    DateTime? at,
    String? note,
  });
}

class AccountWithBalanceAndTransactions {
  const AccountWithBalanceAndTransactions({
    required this.account,
    required this.balance,
    required this.transactions,
  });
  final Account account;
  final int balance;
  final List<TransactionWithDetails> transactions;
}
