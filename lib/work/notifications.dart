import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AppNotifications {
  AppNotifications._();
  static final instance = AppNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const channelBudget = 'budget_alerts';
  static const channelRecurring = 'recurring_due';
  static const channelDaily = 'daily_reminder';
  static const channelWeekly = 'weekly_summary';

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
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
    await android?.requestNotificationsPermission();
    _initialized = true;
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
