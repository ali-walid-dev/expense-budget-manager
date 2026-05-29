class TimeRange {
  const TimeRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime dt) => !dt.isBefore(start) && dt.isBefore(end);

  static TimeRange day(DateTime any) {
    final s = DateTime(any.year, any.month, any.day);
    return TimeRange(s, s.add(const Duration(days: 1)));
  }

  static TimeRange month(DateTime any, {int monthStartDay = 1}) {
    final s = DateTime(any.year, any.month, monthStartDay);
    final e = DateTime(any.year, any.month + 1, monthStartDay);
    return TimeRange(s, e);
  }

  static TimeRange week(DateTime any, {int weekStartDay = DateTime.saturday}) {
    final daysFromStart = (any.weekday - weekStartDay) % 7;
    final s = DateTime(any.year, any.month, any.day)
        .subtract(Duration(days: daysFromStart));
    return TimeRange(s, s.add(const Duration(days: 7)));
  }

  static TimeRange year(DateTime any) {
    return TimeRange(DateTime(any.year, 1, 1), DateTime(any.year + 1, 1, 1));
  }
}
