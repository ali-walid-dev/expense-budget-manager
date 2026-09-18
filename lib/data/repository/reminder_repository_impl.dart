import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/domain/model/reminder.dart';
import 'package:expense_budget_manager/domain/repository/reminder_repository.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl(this.db);
  final d.AppDatabase db;

  @override
  Stream<List<Reminder>> watchAll() =>
      db.reminderDao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<Reminder>> getAll() async =>
      (await db.reminderDao.getAll()).map((r) => r.toDomain()).toList();

  @override
  Future<int> upsert({
    int? id,
    required String message,
    required int hour,
    required int minute,
    required ReminderFrequency frequency,
    required List<int> weekdays,
    bool enabled = true,
  }) async {
    final freq = frequency == ReminderFrequency.weekly ? 'weekly' : 'daily';
    final wd = frequency == ReminderFrequency.weekly
        ? (weekdays.toSet().toList()..sort()).join(',')
        : '';
    if (id == null) {
      return db.reminderDao.insert(d.RemindersCompanion.insert(
        message: message,
        hour: hour,
        minute: minute,
        frequency: Value(freq),
        weekdays: Value(wd),
        enabled: Value(enabled),
      ));
    } else {
      final existing = await db.reminderDao.findById(id);
      if (existing == null) return id;
      await db.reminderDao.update_(existing.copyWith(
        message: message,
        hour: hour,
        minute: minute,
        frequency: freq,
        weekdays: wd,
        enabled: enabled,
      ));
      return id;
    }
  }

  @override
  Future<void> setEnabled(int id, bool enabled) async {
    final existing = await db.reminderDao.findById(id);
    if (existing == null) return;
    await db.reminderDao.update_(existing.copyWith(enabled: enabled));
  }

  @override
  Future<void> delete(int id) async {
    await db.reminderDao.deleteById(id);
  }
}
