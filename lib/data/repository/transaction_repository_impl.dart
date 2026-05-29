import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';
import 'package:expense_budget_manager/domain/repository/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this.db);
  final d.AppDatabase db;

  @override
  Stream<int> watchChangeSignal() => db.transactionDao.watchChangeSignal();

  @override
  Stream<List<TransactionWithDetails>> watchRecent(int limit) => db.transactionDao
      .watchRecent(limit)
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<TransactionWithDetails>> getPage({
    required int offset,
    required int limit,
    String query = '',
  }) async {
    final rows = await db.transactionDao
        .getPage(offset: offset, limit: limit, query: query);
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Stream<List<TransactionWithDetails>> search(String query) async* {
    // Trigger refresh on any change to the table.
    await for (final _ in db.transactionDao.watchChangeSignal()) {
      final rows = await db.transactionDao.getPage(offset: 0, limit: 200, query: query);
      yield rows.map((r) => r.toDomain()).toList();
    }
  }

  @override
  Future<int> insert({
    required int amountMinor,
    required TransactionType type,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required DateTime dateTime,
    String? note,
    int? recurringId,
  }) {
    return db.transactionDao.insert(d.TransactionsCompanion.insert(
      amount: amountMinor.abs(),
      type: type,
      accountId: accountId,
      toAccountId: Value(toAccountId),
      categoryId: Value(categoryId),
      occurredAt: dateTime.millisecondsSinceEpoch,
      note: Value(note),
      recurringId: Value(recurringId),
    ));
  }

  @override
  Future<void> update({
    required int id,
    required int amountMinor,
    required TransactionType type,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required DateTime dateTime,
    String? note,
  }) async {
    final existing = await db.transactionDao.findById(id);
    if (existing == null) return;
    await db.transactionDao.update_(existing.copyWith(
      amount: amountMinor.abs(),
      type: type,
      accountId: accountId,
      toAccountId: Value(toAccountId),
      categoryId: Value(categoryId),
      occurredAt: dateTime.millisecondsSinceEpoch,
      note: Value(note),
    ));
  }

  @override
  Future<void> delete(int id) async {
    await db.transactionDao.deleteById(id);
  }

  @override
  Future<int> duplicate(int id) async {
    final existing = await db.transactionDao.findById(id);
    if (existing == null) return -1;
    return insert(
      amountMinor: existing.amount,
      type: existing.type,
      accountId: existing.accountId,
      toAccountId: existing.toAccountId,
      categoryId: existing.categoryId,
      dateTime: DateTime.now(),
      note: existing.note,
    );
  }

  @override
  Stream<({int income, int expense})> watchTotalsInRange(DateTime start, DateTime end) =>
      db.transactionDao.watchTotalsInRange(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      );

  @override
  Stream<List<CategorySpend>> watchSpendingByCategory(DateTime start, DateTime end) {
    return db.transactionDao
        .watchSpendingByCategory(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
        .map((rows) => rows
            .map((r) => CategorySpend(
                  categoryId: r.categoryId,
                  categoryName: r.name,
                  colorHex: r.colorHex,
                  totalMinor: r.total,
                ))
            .toList());
  }

  @override
  Stream<List<DailySpend>> watchDailyTrend(DateTime start, DateTime end) {
    return db.transactionDao
        .watchDailyTrend(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
        .map((rows) => rows
            .map((r) => DailySpend(
                  day: DateTime.fromMillisecondsSinceEpoch(r.dayMillis),
                  totalMinor: r.total,
                ))
            .toList());
  }

  @override
  Future<int> sumSpendInRange({
    required DateTime start,
    required DateTime end,
    int? categoryId,
  }) =>
      db.transactionDao.sumSpendInRange(
        startMillis: start.millisecondsSinceEpoch,
        endMillis: end.millisecondsSinceEpoch,
        categoryId: categoryId,
      );

  @override
  Future<int> runDueRecurring({DateTime? now}) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final due = await db.recurringDao.dueAsOf(nowMs);
    var created = 0;
    for (final rule in due) {
      final ruleMs = rule.nextRunDate;
      // Idempotency: skip if lastRunDate already covers this slot.
      if (rule.lastRunDate != null && rule.lastRunDate! >= ruleMs) continue;

      await db.transactionDao.insert(d.TransactionsCompanion.insert(
        amount: rule.templateAmount,
        type: rule.type,
        accountId: rule.accountId,
        toAccountId: Value(rule.toAccountId),
        categoryId: Value(rule.categoryId),
        occurredAt: ruleMs,
        note: Value(rule.note),
        recurringId: Value(rule.id),
      ));
      created++;

      final next = _advance(rule.nextRunDate, rule.interval);
      await db.recurringDao.update_(rule.copyWith(
        nextRunDate: next,
        lastRunDate: Value(ruleMs),
      ));
    }
    return created;
  }

  int _advance(int currentMs, RecurringInterval interval) {
    final dt = DateTime.fromMillisecondsSinceEpoch(currentMs);
    final next = switch (interval) {
      RecurringInterval.daily => dt.add(const Duration(days: 1)),
      RecurringInterval.weekly => dt.add(const Duration(days: 7)),
      RecurringInterval.monthly => DateTime(dt.year, dt.month + 1, dt.day, dt.hour, dt.minute),
      RecurringInterval.yearly => DateTime(dt.year + 1, dt.month, dt.day, dt.hour, dt.minute),
    };
    return next.millisecondsSinceEpoch;
  }
}
