import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/data/repository/transaction_repository_impl.dart';
import 'package:expense_budget_manager/work/notifications.dart';

const taskRunRecurring = 'task_run_recurring';

@pragma('vm:entry-point')
void backgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    if (task != taskRunRecurring) return Future.value(true);
    try {
      final db = AppDatabase();
      final repo = TransactionRepositoryImpl(db);
      final created = await repo.runDueRecurring();
      if (created > 0) {
        await AppNotifications.instance.showRecurringDue(
          'Recurring transactions',
          '$created new transaction${created == 1 ? '' : 's'} added',
        );
      }
      await db.close();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('worker error: $e\n$st');
      return false;
    }
  });
}

Future<void> initBackgroundWorker() async {
  await Workmanager().initialize(backgroundCallback, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    taskRunRecurring,
    taskRunRecurring,
    frequency: const Duration(hours: 24),
    initialDelay: const Duration(minutes: 1),
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
