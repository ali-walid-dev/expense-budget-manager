import 'package:flutter/foundation.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/data/repository/transaction_repository_impl.dart';
import 'package:expense_budget_manager/work/notifications.dart';

/// Runs the recurring-transaction catch-up once at app launch. Idempotent —
/// safe to call on every cold start. If the user opens the app daily this
/// achieves the same effect as a background worker.
Future<void> runRecurringCatchUpOnLaunch(AppDatabase db) async {
  try {
    final repo = TransactionRepositoryImpl(db);
    final created = await repo.runDueRecurring();
    if (created > 0) {
      await AppNotifications.instance.showRecurringDue(
        'Recurring transactions',
        '$created new transaction${created == 1 ? '' : 's'} added',
      );
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('runRecurringCatchUpOnLaunch error: $e\n$st');
  }
}
