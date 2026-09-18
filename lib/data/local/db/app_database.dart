import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:expense_budget_manager/data/local/db/converters.dart';
import 'package:expense_budget_manager/data/local/db/daos.dart';
import 'package:expense_budget_manager/data/local/db/tables.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Tags, TransactionTags, Budgets, Debts, RecurringRules, Reminders],
  daos: [AccountDao, CategoryDao, TransactionDao, BudgetDao, DebtDao, RecurringDao, ReminderDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.connect(super.connection);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX idx_tx_date ON transactions(date_time)');
          await customStatement('CREATE INDEX idx_tx_account ON transactions(account_id)');
          await customStatement('CREATE INDEX idx_tx_category ON transactions(category_id)');
          await customStatement('CREATE INDEX idx_tx_recurring ON transactions(recurring_id)');
          await customStatement('CREATE INDEX idx_tx_debt ON transactions(debt_id)');
          await customStatement('CREATE INDEX idx_rr_next ON recurring_rules(next_run_date)');
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2: hierarchical-category support already existed in v1
          // (categories.parent_id). v2 adds: budget names, the debts module,
          // and a debt_id link on transactions. All additive — no existing
          // row is touched.
          if (from < 2) {
            await m.addColumn(budgets, budgets.name);
            await m.createTable(debts);
            await m.addColumn(transactions, transactions.debtId);
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_tx_debt ON transactions(debt_id)');
          }
          // v2 -> v3: reminder notifications.
          if (from < 3) {
            await m.createTable(reminders);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'expense_budget.sqlite'));
    final cache = await getTemporaryDirectory();
    sqlite3.tempDirectory = cache.path;
    return NativeDatabase.createInBackground(file);
  });
}
