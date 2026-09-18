import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:expense_budget_manager/domain/model/reminder.dart';

class AppNotifications {
  AppNotifications._();
  static final instance = AppNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const channelBudget = 'budget_alerts';
  static const channelRecurring = 'recurring_due';
  static const channelDaily = 'daily_reminder';
  static const channelWeekly = 'weekly_summary';
  static const channelReminders = 'user_reminders';

  // Notification ids are derived from the reminder id so they can be cancelled
  // and replaced deterministically. Daily reminders use [_reminderBase]; weekly
  // ones use [_reminderBase] + weekday (1..7).
  static int _reminderBase(int reminderId) => 1000000 + reminderId * 10;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      if (kDebugMode) debugPrint('timezone detect failed: $e');
    }
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(init);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelBudget, 'Budget alerts',
        description: 'Triggered when a budget is exceeded.',
        importance: Importance.high));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelRecurring, 'Recurring payment due',
        description: 'Reminder for upcoming recurring transactions.',
        importance: Importance.defaultImportance));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelDaily, 'Daily expense reminder',
        description: 'Daily nudge to log expenses.',
        importance: Importance.low));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelWeekly, 'Weekly summary',
        description: 'Weekly spending summary.',
        importance: Importance.defaultImportance));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelReminders, 'Reminders',
        description: 'Your custom reminder notifications.',
        importance: Importance.high));
    await android?.requestNotificationsPermission();
    // Exact alarms — appropriate for a reminder feature (USE_EXACT_ALARM in the
    // manifest). No-op where the OS doesn't require it.
    await android?.requestExactAlarmsPermission();
    _initialized = true;
  }

  /// (Re)schedules all enabled reminders and cancels disabled ones. [title] is
  /// the localized notification title (body is the reminder's message).
  Future<void> syncReminders(List<Reminder> reminders, {required String title}) async {
    await init();
    for (final r in reminders) {
      await cancelReminder(r);
      if (r.enabled) await scheduleReminder(r, title: title);
    }
  }

  Future<void> scheduleReminder(Reminder r, {required String title}) async {
    await init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelReminders,
        'Reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final base = _reminderBase(r.id);
    if (r.frequency == ReminderFrequency.weekly && r.weekdays.isNotEmpty) {
      for (final wd in r.weekdays) {
        await _plugin.zonedSchedule(
          base + wd,
          title,
          r.message,
          _nextInstanceOfWeekdayTime(wd, r.hour, r.minute),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } else {
      await _plugin.zonedSchedule(
        base,
        title,
        r.message,
        _nextInstanceOfTime(r.hour, r.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Cancels every notification id a reminder could occupy (daily + all 7
  /// weekday slots), so it works regardless of the reminder's current mode.
  Future<void> cancelReminder(Reminder r) async {
    final base = _reminderBase(r.id);
    await _plugin.cancel(base);
    for (var wd = 1; wd <= 7; wd++) {
      await _plugin.cancel(base + wd);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> showBudgetExceeded(String title, String body) async {
    await init();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelBudget,
          'Budget alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showRecurringDue(String title, String body) async {
    await init();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(channelRecurring, 'Recurring'),
      ),
    );
  }

  Future<void> showDailyReminder(String title, String body) async {
    await init();
    await _plugin.show(
      4242,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(channelDaily, 'Daily reminder'),
      ),
    );
  }
}
