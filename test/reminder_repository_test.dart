import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/data/repository/reminder_repository_impl.dart';
import 'package:expense_budget_manager/domain/model/reminder.dart';

void main() {
  late AppDatabase db;
  late ReminderRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    repo = ReminderRepositoryImpl(db);
  });
  tearDown(() => db.close());

  test('daily reminder stores no weekdays', () async {
    final id = await repo.upsert(
      message: 'Log expenses',
      hour: 21,
      minute: 30,
      frequency: ReminderFrequency.daily,
      weekdays: const [],
    );
    final all = await repo.getAll();
    expect(all, hasLength(1));
    final r = all.single;
    expect(r.id, id);
    expect(r.message, 'Log expenses');
    expect(r.hour, 21);
    expect(r.minute, 30);
    expect(r.frequency, ReminderFrequency.daily);
    expect(r.weekdays, isEmpty);
    expect(r.enabled, isTrue);
  });

  test('weekly reminder round-trips its weekdays (sorted, deduped)', () async {
    await repo.upsert(
      message: 'Gym',
      hour: 7,
      minute: 0,
      frequency: ReminderFrequency.weekly,
      weekdays: const [5, 1, 3, 1],
    );
    final r = (await repo.getAll()).single;
    expect(r.frequency, ReminderFrequency.weekly);
    expect(r.weekdays, [1, 3, 5]);
  });

  test('setEnabled toggles persistence; edit updates fields', () async {
    final id = await repo.upsert(
      message: 'A',
      hour: 8,
      minute: 0,
      frequency: ReminderFrequency.daily,
      weekdays: const [],
    );
    await repo.setEnabled(id, false);
    expect((await repo.getAll()).single.enabled, isFalse);

    await repo.upsert(
      id: id,
      message: 'B',
      hour: 9,
      minute: 15,
      frequency: ReminderFrequency.weekly,
      weekdays: const [6, 7],
      enabled: true,
    );
    final r = (await repo.getAll()).single;
    expect(r.message, 'B');
    expect(r.hour, 9);
    expect(r.minute, 15);
    expect(r.frequency, ReminderFrequency.weekly);
    expect(r.weekdays, [6, 7]);
    expect(r.enabled, isTrue);
  });

  test('delete removes the reminder', () async {
    final id = await repo.upsert(
      message: 'X',
      hour: 1,
      minute: 1,
      frequency: ReminderFrequency.daily,
      weekdays: const [],
    );
    await repo.delete(id);
    expect(await repo.getAll(), isEmpty);
  });
}
