import 'package:expense_budget_manager/domain/model/reminder.dart';

abstract class ReminderRepository {
  Stream<List<Reminder>> watchAll();
  Future<List<Reminder>> getAll();

  Future<int> upsert({
    int? id,
    required String message,
    required int hour,
    required int minute,
    required ReminderFrequency frequency,
    required List<int> weekdays,
    bool enabled = true,
  });

  Future<void> setEnabled(int id, bool enabled);
  Future<void> delete(int id);
}
