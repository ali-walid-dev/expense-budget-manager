import 'dart:async';

import 'package:drift/drift.dart';

import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/domain/repository/budget_repository.dart';
import 'package:expense_budget_manager/domain/repository/settings_repository.dart';
import 'package:expense_budget_manager/domain/repository/transaction_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this.db, this.tx, this.settings);
  final d.AppDatabase db;
  final TransactionRepository tx;
  final SettingsRepository settings;

  @override
  Stream<List<Budget>> watchAll() =>
      db.budgetDao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Stream<List<BudgetProgress>> watchProgress() {
    // Re-emit whenever budgets, transactions, or settings change.
    final controller = StreamController<List<BudgetProgress>>.broadcast();
    final subs = <StreamSubscription>[];

    Future<void> recompute() async {
      try {
        final budgets = await db.budgetDao.watchAll().first;
        final categories = await db.select(db.categories).get();
        final s = settings.current;
        final results = <BudgetProgress>[];
        for (final b in budgets) {
          final domain = b.toDomain();
          final range = _rangeFor(domain, s);
          final spent = await tx.sumSpendInRange(
            start: range.start,
            end: range.end,
            categoryId: b.categoryId,
          );
          final name = b.categoryId == null
              ? null
              : categories
                  .where((c) => c.id == b.categoryId)
                  .map((c) => c.name)
                  .firstOrNull;
          results.add(BudgetProgress(
            budget: domain,
            spentMinor: spent,
            categoryName: name,
          ));
        }
        controller.add(results);
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    controller.onListen = () {
      subs.add(db.budgetDao.watchAll().listen((_) => recompute()));
      subs.add(tx.watchChangeSignal().listen((_) => recompute()));
      subs.add(settings.watch().listen((_) => recompute()));
      recompute();
    };
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }

  TimeRange _rangeFor(Budget b, AppSettings s) {
    switch (b.period) {
      case BudgetPeriod.weekly:
        return TimeRange.week(DateTime.now(), weekStartDay: s.weekStartDay);
      case BudgetPeriod.monthly:
        return TimeRange.month(DateTime.now(), monthStartDay: s.budgetStartDay);
      case BudgetPeriod.custom:
        return TimeRange(
          b.startDate ?? DateTime.now(),
          b.endDate ?? DateTime.now().add(const Duration(days: 30)),
        );
    }
  }

  @override
  Future<int> upsert({
    int? id,
    required int amountMinor,
    required BudgetPeriod period,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool carryOver = false,
  }) async {
    if (id == null) {
      return db.budgetDao.insert(d.BudgetsCompanion.insert(
        categoryId: Value(categoryId),
        amount: amountMinor,
        period: period,
        startDate: Value(startDate?.millisecondsSinceEpoch),
        endDate: Value(endDate?.millisecondsSinceEpoch),
        carryOver: Value(carryOver),
      ));
    } else {
      final existing = await (db.select(db.budgets)..where((b) => b.id.equals(id))).getSingle();
      await db.budgetDao.update_(existing.copyWith(
        categoryId: Value(categoryId),
        amount: amountMinor,
        period: period,
        startDate: Value(startDate?.millisecondsSinceEpoch),
        endDate: Value(endDate?.millisecondsSinceEpoch),
        carryOver: carryOver,
      ));
      return id;
    }
  }

  @override
  Future<void> delete(int id) async {
    await db.budgetDao.deleteById(id);
  }
}
