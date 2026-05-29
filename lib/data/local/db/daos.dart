import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/data/local/db/tables.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Accounts, Transactions])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Stream<List<Account>> watchAll() =>
      (select(accounts)..where((a) => a.archived.equals(false))).watch();

  Future<int> insert(AccountsCompanion c) => into(accounts).insert(c);
  Future<bool> update_(AccountsCompanion c) => update(accounts).replace(c);
  Future<int> deleteById(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  /// Computed balance via SQL: initialBalance + SUM(income) - SUM(expense)
  /// + SUM(transfers in) - SUM(transfers out).
  Stream<List<({Account account, int balance})>> watchAllWithBalance() {
    final sumIncome = customExpression<int>(
        "COALESCE(SUM(CASE WHEN t.type='income' AND t.account_id=a.id THEN t.amount ELSE 0 END), 0)");
    final sumExpense = customExpression<int>(
        "COALESCE(SUM(CASE WHEN t.type='expense' AND t.account_id=a.id THEN t.amount ELSE 0 END), 0)");
    final sumTransferOut = customExpression<int>(
        "COALESCE(SUM(CASE WHEN t.type='transfer' AND t.account_id=a.id THEN t.amount ELSE 0 END), 0)");
    final sumTransferIn = customExpression<int>(
        "COALESCE(SUM(CASE WHEN t.type='transfer' AND t.to_account_id=a.id THEN t.amount ELSE 0 END), 0)");

    final q = customSelect(
      '''
      SELECT a.*,
        (a.initial_balance + $sumIncome - $sumExpense + $sumTransferIn - $sumTransferOut) AS balance
      FROM accounts a
      LEFT JOIN transactions t ON t.account_id = a.id OR t.to_account_id = a.id
      WHERE a.archived = 0
      GROUP BY a.id
      ORDER BY a.id ASC
      ''',
      readsFrom: {accounts, transactions},
    );
    return q.watch().map((rows) {
      return rows.map((r) {
        final account = accounts.map(r.data);
        return (account: account, balance: r.read<int>('balance'));
      }).toList();
    });
  }

  Stream<({Account account, int balance})?> watchOneWithBalance(int id) =>
      watchAllWithBalance().map(
        (rows) => rows.where((r) => r.account.id == id).firstOrNull,
      );
}

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchAll() => select(categories).watch();
  Future<int> insert(CategoriesCompanion c) => into(categories).insert(c);
  Future<bool> update_(CategoriesCompanion c) => update(categories).replace(c);
  Future<int> deleteById(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();
}

@DriftAccessor(tables: [Transactions, Accounts, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<int> insert(TransactionsCompanion c) => into(transactions).insert(c);
  Future<bool> update_(TransactionsCompanion c) =>
      update(transactions).replace(c);
  Future<int> deleteById(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<Transaction?> findById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Paged query joined with category + account.
  Future<List<TxJoinedRow>> getPage({
    required int offset,
    required int limit,
    String query = '',
  }) async {
    final qLike = query.isEmpty ? null : '%${query.toLowerCase()}%';
    final result = await customSelect(
      '''
      SELECT t.*,
        c.name AS category_name,
        c.color_hex AS category_color,
        c.icon_key AS category_icon,
        a.name AS account_name
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      ${qLike != null ? "WHERE LOWER(IFNULL(t.note,'')) LIKE ? OR LOWER(IFNULL(c.name,'')) LIKE ? OR LOWER(a.name) LIKE ?" : ''}
      ORDER BY t.date_time DESC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        if (qLike != null) Variable.withString(qLike),
        if (qLike != null) Variable.withString(qLike),
        if (qLike != null) Variable.withString(qLike),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
      readsFrom: {transactions, categories, accounts},
    ).get();
    return result.map(TxJoinedRow.fromRow).toList();
  }

  /// A pulse stream that fires whenever transactions change — used by paged
  /// lists to refresh their controller.
  Stream<int> watchChangeSignal() =>
      (selectOnly(transactions)..addColumns([transactions.id.count()]))
          .watchSingle()
          .map((row) => row.read(transactions.id.count()) ?? 0);

  /// Recent N transactions joined for dashboard.
  Stream<List<TxJoinedRow>> watchRecent(int limit) {
    return customSelect(
      '''
      SELECT t.*,
        c.name AS category_name,
        c.color_hex AS category_color,
        c.icon_key AS category_icon,
        a.name AS account_name
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      ORDER BY t.date_time DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {transactions, categories, accounts},
    ).watch().map((rows) => rows.map(TxJoinedRow.fromRow).toList());
  }

  Stream<List<TxJoinedRow>> watchForAccount(int accountId) {
    return customSelect(
      '''
      SELECT t.*,
        c.name AS category_name,
        c.color_hex AS category_color,
        c.icon_key AS category_icon,
        a.name AS account_name
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE t.account_id = ? OR t.to_account_id = ?
      ORDER BY t.date_time DESC
      LIMIT 200
      ''',
      variables: [Variable.withInt(accountId), Variable.withInt(accountId)],
      readsFrom: {transactions, categories, accounts},
    ).watch().map((rows) => rows.map(TxJoinedRow.fromRow).toList());
  }

  /// Sums by type for a date range.
  Stream<({int income, int expense})> watchTotalsInRange(
      int startMillis, int endMillis) {
    return customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions
      WHERE date_time >= ? AND date_time < ?
      ''',
      variables: [Variable.withInt(startMillis), Variable.withInt(endMillis)],
      readsFrom: {transactions},
    ).watchSingle().map((r) => (
          income: r.read<int>('income'),
          expense: r.read<int>('expense'),
        ));
  }

  /// Spend per category in a range — descending.
  Stream<List<({int categoryId, String name, String colorHex, int total})>>
      watchSpendingByCategory(int startMillis, int endMillis) {
    return customSelect(
      '''
      SELECT c.id, c.name, c.color_hex, COALESCE(SUM(t.amount), 0) AS total
      FROM transactions t
      INNER JOIN categories c ON c.id = t.category_id
      WHERE t.type='expense' AND t.date_time >= ? AND t.date_time < ?
      GROUP BY c.id
      ORDER BY total DESC
      ''',
      variables: [Variable.withInt(startMillis), Variable.withInt(endMillis)],
      readsFrom: {transactions, categories},
    ).watch().map((rows) => rows.map((r) => (
              categoryId: r.read<int>('id'),
              name: r.read<String>('name'),
              colorHex: r.read<String>('color_hex'),
              total: r.read<int>('total'),
            )).toList());
  }

  /// Spend per day in a range (for line chart).
  Stream<List<({int dayMillis, int total})>> watchDailyTrend(
      int startMillis, int endMillis) {
    return customSelect(
      '''
      SELECT
        (date_time / 86400000) * 86400000 AS day_millis,
        SUM(amount) AS total
      FROM transactions
      WHERE type='expense' AND date_time >= ? AND date_time < ?
      GROUP BY day_millis
      ORDER BY day_millis ASC
      ''',
      variables: [Variable.withInt(startMillis), Variable.withInt(endMillis)],
      readsFrom: {transactions},
    ).watch().map((rows) => rows.map((r) => (
              dayMillis: r.read<int>('day_millis'),
              total: r.read<int>('total'),
            )).toList());
  }

  Future<int> sumSpendInRange({
    required int startMillis,
    required int endMillis,
    int? categoryId,
  }) async {
    final r = await customSelect(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total FROM transactions
      WHERE type='expense' AND date_time >= ? AND date_time < ?
      ${categoryId == null ? '' : 'AND category_id = ?'}
      ''',
      variables: [
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
        if (categoryId != null) Variable.withInt(categoryId),
      ],
      readsFrom: {transactions},
    ).getSingle();
    return r.read<int>('total');
  }
}

class TxJoinedRow {
  TxJoinedRow({
    required this.id,
    required this.amount,
    required this.typeName,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.dateTime,
    required this.note,
    required this.recurringId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.accountName,
  });

  final int id;
  final int amount;
  final String typeName;
  final int? categoryId;
  final int accountId;
  final int? toAccountId;
  final int dateTime;
  final String? note;
  final int? recurringId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final String accountName;

  TransactionType get type => TransactionType.values
      .firstWhere((e) => e.name == typeName, orElse: () => TransactionType.expense);

  static TxJoinedRow fromRow(QueryRow r) => TxJoinedRow(
        id: r.read<int>('id'),
        amount: r.read<int>('amount'),
        typeName: r.read<String>('type'),
        categoryId: r.readNullable<int>('category_id'),
        accountId: r.read<int>('account_id'),
        toAccountId: r.readNullable<int>('to_account_id'),
        dateTime: r.read<int>('date_time'),
        note: r.readNullable<String>('note'),
        recurringId: r.readNullable<int>('recurring_id'),
        categoryName: r.readNullable<String>('category_name'),
        categoryColor: r.readNullable<String>('category_color'),
        categoryIcon: r.readNullable<String>('category_icon'),
        accountName: r.read<String>('account_name'),
      );
}

@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);
  Stream<List<Budget>> watchAll() => select(budgets).watch();
  Future<int> insert(BudgetsCompanion c) => into(budgets).insert(c);
  Future<bool> update_(BudgetsCompanion c) => update(budgets).replace(c);
  Future<int> deleteById(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();
}

@DriftAccessor(tables: [RecurringRules])
class RecurringDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringDaoMixin {
  RecurringDao(super.db);
  Stream<List<RecurringRule>> watchAll() => select(recurringRules).watch();
  Future<List<RecurringRule>> dueAsOf(int millis) =>
      (select(recurringRules)..where((r) => r.nextRunDate.isSmallerOrEqualValue(millis)))
          .get();
  Future<int> insert(RecurringRulesCompanion c) => into(recurringRules).insert(c);
  Future<bool> update_(RecurringRulesCompanion c) =>
      update(recurringRules).replace(c);
  Future<int> deleteById(int id) =>
      (delete(recurringRules)..where((r) => r.id.equals(id))).go();
}
