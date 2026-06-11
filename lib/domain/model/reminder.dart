enum ReminderFrequency { daily, weekly }

class Reminder {
  const Reminder({
    required this.id,
    required this.message,
    required this.hour,
    required this.minute,
    required this.frequency,
    required this.weekdays,
    required this.enabled,
  });

  final int id;
  final String message;
  final int hour; // 0-23
  final int minute; // 0-59
  final ReminderFrequency frequency;
  // DateTime weekday ints (1=Mon..7=Sun). Empty for daily.
  final List<int> weekdays;
  final bool enabled;
}
