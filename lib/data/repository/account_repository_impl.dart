import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/repository/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this.db);
  final d.AppDatabase db;

  @override
  Stream<List<Account>> watchAll() =>
      db.accountDao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Stream<List<AccountWithBalance>> watchAllWithBalance() {
    return db.accountDao.watchAllWithBalance().map(
          (rows) => rows
              .map((r) => AccountWithBalance(
                    account: r.account.toDomain(),
                    balance: r.balance,
                  ))
              .toList(),
        );
  }

  @override
  Stream<AccountWithBalanceAndTransactions?> watchOneDetail(int id) {
    return db.accountDao.watchOneWithBalance(id).asyncMap((row) async {
      if (row == null) return null;
      final txs = await db.transactionDao.watchForAccount(id).first;
      return AccountWithBalanceAndTransactions(
        account: row.account.toDomain(),
        balance: row.balance,
        transactions: txs.map((r) => r.toDomain()).toList(),
      );
    });
  }

  @override
  Future<int> upsert({
    int? id,
    required String name,
    required AccountType type,
    required int initialBalance,
    required Color color,
    String currency = 'EGP',
  }) async {
    final colorHex = colorToHex(color);
    if (id == null) {
      return db.accountDao.insert(d.AccountsCompanion.insert(
        name: name,
        type: type,
        currency: Value(currency),
        initialBalance: Value(initialBalance),
        colorHex: Value(colorHex),
      ));
    } else {
      final existing = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
      await db.accountDao.update_(existing.copyWith(
        name: name,
        type: type,
        currency: currency,
        initialBalance: initialBalance,
        colorHex: colorHex,
      ));
      return id;
    }
  }

  @override
  Future<void> delete(int id) async {
    await db.accountDao.deleteById(id);
  }

  @override
  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    DateTime? at,
    String? note,
  }) async {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    await db.transactionDao.insert(d.TransactionsCompanion.insert(
      amount: amountMinor,
      type: TransactionType.transfer,
      accountId: fromAccountId,
      toAccountId: Value(toAccountId),
      dateTime: ts,
      note: Value(note),
    ));
  }
}
