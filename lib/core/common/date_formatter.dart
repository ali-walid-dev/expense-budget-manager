import 'package:intl/intl.dart';

import 'package:expense_budget_manager/core/common/money_formatter.dart';

class DateFormatter {
  DateFormatter({required this.localeTag, this.digitFormat = DigitFormat.latin});

  final String localeTag;
  final DigitFormat digitFormat;

  String dayMonth(DateTime dt) => _shape(DateFormat.MMMd(localeTag).format(dt));
  String full(DateTime dt) => _shape(DateFormat.yMMMMd(localeTag).format(dt));
  String time(DateTime dt) => _shape(DateFormat.Hm(localeTag).format(dt));
  String dateTime(DateTime dt) => '${full(dt)} ${time(dt)}';
  String monthYear(DateTime dt) =>
      _shape(DateFormat.yMMMM(localeTag).format(dt));
  String weekday(DateTime dt) => _shape(DateFormat.EEEE(localeTag).format(dt));

  String _shape(String input) {
    if (digitFormat == DigitFormat.arabic && localeTag.startsWith('ar')) {
      return input;
    }
    if (digitFormat == DigitFormat.latin && localeTag.startsWith('ar')) {
      return _toLatinDigits(input);
    }
    return input;
  }

  static String _toLatinDigits(String input) {
    final buf = StringBuffer();
    for (final ch in input.runes) {
      if (ch >= 0x0660 && ch <= 0x0669) {
        buf.writeCharCode(0x30 + (ch - 0x0660));
      } else if (ch >= 0x06F0 && ch <= 0x06F9) {
        buf.writeCharCode(0x30 + (ch - 0x06F0));
      } else {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }
}
