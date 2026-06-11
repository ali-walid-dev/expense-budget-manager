import 'dart:async';

import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/domain/model/debt.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/repository/debt_repository.dart';

class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this.db);
  final d.AppDatabase db;

  @override
  Stream<List<DebtProgress>> watchAll() {
    final controller = StreamController<List<DebtProgress>>.broadcast();
    final subs = <StreamSubscription>[];

    Future<void> recompute() async {
      try {
        final rows = await db.debtDao.getAll();
        final result = <DebtProgress>[];
        for (final row in rows) {
          final debt = row.toDomain();
          final paid = await db.debtDao.paidAmount(debt.id);
          result.add(DebtProgress(
            debt: debt,
            paidMinor: paid,
            nextPaymentDate: _nextPaymentDate(debt, paid),
          ));
        }
        controller.add(result);
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    controller.onListen = () {
      subs.add(db.debtDao.watchChangeSignal().listen((_) => recompute()));
      subs.add(db.transactionDao.watchChangeSignal().listen((_) => recompute()));
      recompute();
    };
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }

  @override
  Future<Debt?> getById(int id) async {
    final row = await db.debtDao.findById(id);
    return row?.toDomain();
  }

  @override
  Future<int> upsert({
    int? id,
    required String name,
    String? creditor,
    required int totalAmountMinor,
    required int monthlyPaymentMinor,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
    required int accountId,
    int? categoryId,
  }) async {
    if (id == null) {
      return db.debtDao.insert(d.DebtsCompanion.insert(
        name: name,
        creditor: Value(creditor),
        totalAmount: totalAmountMinor,
        monthlyPayment: monthlyPaymentMinor,
        startDate: startDate.millisecondsSinceEpoch,
        dueDate: Value(dueDate?.millisecondsSinceEpoch),
        note: Value(note),
        accountId: accountId,
        categoryId: Value(categoryId),
      ));
    } else {
      final existing = await db.debtDao.findById(id);
      if (existing == null) return id;
      // Editing recalculates only future cycles — past generated payments are
      // kept untouched (Feature 4 policy). Recompute status from the new total.
      final paid = await db.debtDao.paidAmount(id);
      await db.debtDao.update_(existing.copyWith(
        name: name,
        creditor: Value(creditor),
        totalAmount: totalAmountMinor,
        monthlyPayment: monthlyPaymentMinor,
        startDate: startDate.millisecondsSinceEpoch,
        dueDate: Value(dueDate?.millisecondsSinceEpoch),
        note: Value(note),
        accountId: accountId,
        categoryId: Value(categoryId),
        status: paid >= totalAmountMinor ? 'completed' : 'active',
      ));
      return id;
    }
  }

  @override
  Future<void> delete(int id) async {
    await db.debtDao.deleteById(id);
  }

  @override
  Future<int> runDueDebts({DateTime? now}) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final debts = await db.debtDao.getAll();
    var created = 0;

    for (final debt in debts) {
      if (debt.status == 'completed') continue;
      if (debt.monthlyPayment <= 0 || debt.totalAmount <= 0) continue;

      var paid = await db.debtDao.paidAmount(debt.id);
      var lastGen = debt.lastGeneratedDate;
      var cycle = DateTime.fromMillisecondsSinceEpoch(debt.startDate);

      while (cycle.millisecondsSinceEpoch <= nowMs && paid < debt.totalAmount) {
        final cycleMs = cycle.millisecondsSinceEpoch;
        // Idempotency: skip cycles already covered (by recorded watermark or by
        // an existing linked payment at this exact cycle timestamp).
        final already = (lastGen != null && cycleMs <= lastGen) ||
            await db.debtDao.hasPaymentAt(debt.id, cycleMs);
        if (!already) {
          final remaining = debt.totalAmount - paid;
          final amount = remaining < debt.monthlyPayment
              ? remaining
              : debt.monthlyPayment;
          await db.transactionDao.insert(d.TransactionsCompanion.insert(
            amount: amount,
            type: TransactionType.expense,
            accountId: debt.accountId,
            categoryId: Value(debt.categoryId),
            occurredAt: cycleMs,
            note: Value(debt.name),
            debtId: Value(debt.id),
          ));
          paid += amount;
          created++;
          if (lastGen == null || cycleMs > lastGen) lastGen = cycleMs;
        }
        cycle = _addMonth(cycle);
      }

      final completed = paid >= debt.totalAmount;
      if (lastGen != debt.lastGeneratedDate ||
          (completed && debt.status != 'completed')) {
        await db.debtDao.update_(debt.copyWith(
          lastGeneratedDate: Value(lastGen),
          status: completed ? 'completed' : 'active',
        ));
      }
    }
    return created;
  }

  /// The next cycle that would be generated, or null if the debt is paid off.
  DateTime? _nextPaymentDate(Debt debt, int paid) {
    if (debt.status == DebtStatus.completed || paid >= debt.totalAmount) {
      return null;
    }
    if (debt.lastGeneratedDate == null) return debt.startDate;
    return _addMonth(debt.lastGeneratedDate!);
  }

  /// Adds one calendar month, preserving day-of-month where possible.
  static DateTime _addMonth(DateTime dt) =>
      DateTime(dt.year, dt.month + 1, dt.day, dt.hour, dt.minute);
}
