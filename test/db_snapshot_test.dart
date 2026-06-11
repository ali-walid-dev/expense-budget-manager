import 'package:collection/collection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// Populates every backed-up table with representative data, including the
/// tricky bits: self-referencing categories, transfers, tag links, nullable
/// columns, Arabic text, and REAL values.
Future<void> seedRichData(AppDatabase db) async {
  Future<void> run(String sql) => db.customStatement(sql);

  await run("INSERT INTO accounts (id, name, type, currency, initial_balance) "
      "VALUES (1, 'Cash', 'cash', 'EGP', 10000), (2, 'Bank', 'bank', 'EGP', 500000)");
  await run("INSERT INTO categories (id, name, parent_id, type, is_default) VALUES "
      "(1, 'Food', NULL, 'expense', 1), "
      "(2, 'مطاعم', 1, 'expense', 0), "
      "(3, 'Salary', NULL, 'income', 1)");
  await run("INSERT INTO recurring_rules (id, template_amount, type, category_id, account_id, interval, next_run_date) "
      "VALUES (1, 9900, 'expense', 1, 1, 'monthly', 1750000000000)");
  await run("INSERT INTO debts (id, name, creditor, total_amount, monthly_payment, start_date, account_id, status) "
      "VALUES (1, 'Car Loan', 'البنك الأهلي', 10000000, 200000, 1700000000000, 2, 'active')");
  await run("INSERT INTO transactions (id, amount, type, category_id, account_id, to_account_id, date_time, note, recurring_id, debt_id, latitude, longitude) VALUES "
      "(1, 5500, 'expense', 2, 1, NULL, 1700000001000, 'غداء - lunch', NULL, NULL, 30.0444, 31.2357), "
      "(2, 1000000, 'income', 3, 2, NULL, 1700000002000, NULL, NULL, NULL, NULL, NULL), "
      "(3, 25000, 'transfer', NULL, 2, 1, 1700000003000, 'to cash', NULL, NULL, NULL, NULL), "
      "(4, 200000, 'expense', NULL, 2, NULL, 1700000004000, 'Car Loan', NULL, 1, NULL, NULL), "
      "(5, 9900, 'expense', 1, 1, NULL, 1700000005000, 'subscription', 1, NULL, NULL, NULL)");
  await run("INSERT INTO tags (id, name) VALUES (1, 'work'), (2, 'شخصي')");
  await run("INSERT INTO transaction_tags (transaction_id, tag_id) VALUES (1, 1), (1, 2)");
  await run("INSERT INTO budgets (id, name, category_id, amount, period, start_date, carry_over) "
      "VALUES (1, 'Food cap', 1, 300000, 'monthly', 1700000000000, 1)");
  await run("INSERT INTO reminders (id, message, hour, minute, frequency, weekdays, enabled) "
      "VALUES (1, 'سجل مصاريفك', 21, 30, 'weekly', '1,3,5', 1)");
}

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase.connect(NativeDatabase.memory());
    target = AppDatabase.connect(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('dump -> restore -> dump is byte-for-byte equivalent', () async {
    await seedRichData(source);
    final original = await dumpDatabase(source);

    // Target has pre-existing junk that must be fully replaced.
    await target.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (99, 'Old', 'cash')");

    await restoreDatabase(target, original);
    final roundTripped = await dumpDatabase(target);

    expect(const DeepCollectionEquality().equals(roundTripped, original), isTrue,
        reason: 'restored snapshot must equal the original exactly');
    // Junk gone.
    expect(roundTripped['accounts']!.map((r) => r['id']), isNot(contains(99)));
  });

  test('restore is atomic — a corrupted row rolls everything back', () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);
    // Inject an unknown column into one row (simulates damaged/newer file).
    snapshot['transactions']![2]['bogus_column'] = 42;

    await target.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (7, 'Keep me', 'cash')");
    final before = await dumpDatabase(target);

    await expectLater(
      restoreDatabase(target, snapshot),
      throwsA(isA<CorruptBackupFailure>()),
    );

    final after = await dumpDatabase(target);
    expect(const DeepCollectionEquality().equals(after, before), isTrue,
        reason: 'failed restore must leave existing data untouched');
  });

  test('unknown table -> CorruptBackupFailure', () async {
    await expectLater(
      restoreDatabase(target, {
        'evil_table': [
          {'id': 1}
        ]
      }),
      throwsA(isA<CorruptBackupFailure>()),
    );
  });

  test('older-schema rows (missing columns) restore with defaults', () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);
    // Simulate a backup taken before debt support existed: rows have no
    // debt_id key at all.
    snapshot['transactions'] =
        snapshot['transactions']!.map((r) => Map<String, Object?>.from(r)..remove('debt_id')).toList();
    snapshot.remove('debts');

    await restoreDatabase(target, snapshot);

    final rows = await target.customSelect('SELECT id, debt_id FROM transactions').get();
    expect(rows, hasLength(5));
    for (final r in rows) {
      expect(r.readNullable<int>('debt_id'), isNull);
    }
  });

  test('restore into a database with live data fully replaces it', () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);

    // Target gets different data first.
    await target.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (1, 'Other', 'bank')");
    await target.customStatement(
        "INSERT INTO categories (id, name, type) VALUES (50, 'X', 'expense')");
    await target.customStatement(
        "INSERT INTO transactions (id, amount, type, category_id, account_id, date_time) "
        "VALUES (900, 1, 'expense', 50, 1, 1)");

    await restoreDatabase(target, snapshot);
    final after = await dumpDatabase(target);
    expect(const DeepCollectionEquality().equals(after, snapshot), isTrue);
  });
}
