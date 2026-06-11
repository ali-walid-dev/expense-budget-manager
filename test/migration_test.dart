import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';

/// The schema exactly as it shipped at v1 (before budgets.name, the debts
/// table, and transactions.debt_id). We build a real database at this version
/// with user data, then open it through the current AppDatabase (v2) to prove
/// the upgrade is non-destructive — the requirement in Part C.
const _v1Schema = <String>[
  '''
  CREATE TABLE accounts (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'EGP',
    initial_balance INTEGER NOT NULL DEFAULT 0,
    color_hex TEXT NOT NULL DEFAULT '#16B981',
    icon_key TEXT NOT NULL DEFAULT 'payments',
    archived INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE categories (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    parent_id INTEGER REFERENCES categories (id),
    type TEXT NOT NULL,
    color_hex TEXT NOT NULL DEFAULT '#16B981',
    icon_key TEXT NOT NULL DEFAULT 'category',
    is_default INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE transactions (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    amount INTEGER NOT NULL,
    type TEXT NOT NULL,
    category_id INTEGER REFERENCES categories (id),
    account_id INTEGER NOT NULL REFERENCES accounts (id),
    to_account_id INTEGER REFERENCES accounts (id),
    date_time INTEGER NOT NULL,
    note TEXT,
    attachment_path TEXT,
    recurring_id INTEGER,
    latitude REAL,
    longitude REAL
  )''',
  '''
  CREATE TABLE budgets (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER REFERENCES categories (id),
    amount INTEGER NOT NULL,
    period TEXT NOT NULL,
    start_date INTEGER,
    end_date INTEGER,
    carry_over INTEGER NOT NULL DEFAULT 0
  )''',
];

void main() {
  test('v1 -> current upgrade keeps existing rows and adds new schema', () async {
    final raw = sqlite3.openInMemory();
    for (final stmt in _v1Schema) {
      raw.execute(stmt);
    }
    // Seed real user data at v1.
    raw.execute(
        "INSERT INTO accounts (id, name, type) VALUES (1, 'Cash', 'cash')");
    raw.execute(
        "INSERT INTO categories (id, name, type) VALUES (1, 'Food', 'expense')");
    raw.execute(
        "INSERT INTO transactions (amount, type, category_id, account_id, date_time, note) "
        "VALUES (5500, 'expense', 1, 1, 1700000000000, 'lunch')");
    raw.execute(
        "INSERT INTO budgets (category_id, amount, period) VALUES (1, 100000, 'monthly')");
    raw.execute('PRAGMA user_version = 1');

    // Open through the v2 database — triggers onUpgrade(1, 2).
    final db = AppDatabase.connect(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Existing transaction survived with all fields intact.
    final txs = await db.transactionDao.getPage(offset: 0, limit: 10);
    expect(txs, hasLength(1));
    expect(txs.first.amount, 5500);
    expect(txs.first.note, 'lunch');
    expect(txs.first.categoryName, 'Food');

    // Existing budget survived; the new (nullable) name column exists.
    final budgetRows =
        await db.customSelect('SELECT id, name, amount FROM budgets').get();
    expect(budgetRows, hasLength(1));
    expect(budgetRows.first.read<int>('amount'), 100000);
    expect(budgetRows.first.readNullable<String>('name'), isNull);

    // New debt_id column and debts table exist and are usable.
    final debtIdRows =
        await db.customSelect('SELECT debt_id FROM transactions').get();
    expect(debtIdRows.first.readNullable<int>('debt_id'), isNull);

    final debtCount =
        await db.customSelect('SELECT COUNT(*) AS c FROM debts').getSingle();
    expect(debtCount.read<int>('c'), 0);

    // v3 reminders table exists.
    final reminderCount =
        await db.customSelect('SELECT COUNT(*) AS c FROM reminders').getSingle();
    expect(reminderCount.read<int>('c'), 0);

    // Schema version is now current (3) — the v1 DB upgrades through all steps.
    final version =
        await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 3);
  });
}
