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
  tables: [Accounts, Categories, Transactions, Tags, TransactionTags, Budgets, RecurringRules],
  daos: [AccountDao, CategoryDao, TransactionDao, BudgetDao, RecurringDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.connect(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX idx_tx_date ON transactions(date_time)');
          await customStatement('CREATE INDEX idx_tx_account ON transactions(account_id)');
          await customStatement('CREATE INDEX idx_tx_category ON transactions(category_id)');
          await customStatement('CREATE INDEX idx_tx_recurring ON transactions(recurring_id)');
          await customStatement('CREATE INDEX idx_rr_next ON recurring_rules(next_run_date)');
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
