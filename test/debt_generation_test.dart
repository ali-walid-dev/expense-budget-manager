import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/data/repository/debt_repository_impl.dart';

void main() {
  late AppDatabase db;
  late DebtRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase.connect(NativeDatabase.memory());
    repo = DebtRepositoryImpl(db);
    // Seed an account and a Car Loan: 100,000 total / 2,000 monthly.
    await db.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (1, 'Cash', 'cash')");
    final startMs = DateTime(2024, 1, 15).millisecondsSinceEpoch;
    await db.customStatement(
        "INSERT INTO debts (id, name, total_amount, monthly_payment, start_date, account_id, status) "
        "VALUES (1, 'Car Loan', 10000000, 200000, $startMs, 1, 'active')");
  });

  tearDown(() async => db.close());

  Future<int> paid() => db.debtDao.paidAmount(1);
  Future<String> status() async {
    final d = await db.debtDao.findById(1);
    return d!.status;
  }

  test('generates one payment per elapsed cycle (catch-up)', () async {
    final created = await repo.runDueDebts(now: DateTime(2024, 3, 20));
    expect(created, 3); // Jan 15, Feb 15, Mar 15
    expect(await paid(), 600000);
    expect(await status(), 'active');
  });

  test('is idempotent — re-running creates no duplicates', () async {
    await repo.runDueDebts(now: DateTime(2024, 3, 20));
    final secondRun = await repo.runDueDebts(now: DateTime(2024, 3, 20));
    expect(secondRun, 0);
    expect(await paid(), 600000);
  });

  test('catches up additional cycles on a later run', () async {
    await repo.runDueDebts(now: DateTime(2024, 3, 20));
    final more = await repo.runDueDebts(now: DateTime(2024, 6, 20));
    expect(more, 3); // Apr, May, Jun
    expect(await paid(), 1200000);
  });

  test('stops at payoff and flips status to completed', () async {
    // Far in the future: should generate exactly 50 payments, no overshoot.
    final created = await repo.runDueDebts(now: DateTime(2035, 1, 1));
    expect(created, 50);
    expect(await paid(), 10000000);
    expect(await status(), 'completed');

    // Completed debts generate nothing further.
    final again = await repo.runDueDebts(now: DateTime(2036, 1, 1));
    expect(again, 0);
  });
}
