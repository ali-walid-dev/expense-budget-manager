import 'package:intl/intl.dart';

enum DigitFormat { latin, arabic }

/// Money is stored as Long minor units (e.g. piastres / cents) per the doc.
/// [MoneyFormatter] is the single place that produces display strings.
class MoneyFormatter {
  MoneyFormatter({
    required this.currencyCode,
    this.fractionDigits = 2,
    this.digitFormat = DigitFormat.latin,
    String? locale,
  }) : _nf = NumberFormat.decimalPatternDigits(
          locale: locale ?? (digitFormat == DigitFormat.arabic ? 'ar' : 'en'),
          decimalDigits: fractionDigits,
        );

  final String currencyCode;
  final int fractionDigits;
  final DigitFormat digitFormat;
  final NumberFormat _nf;

  double _toMajor(int minor) => minor / _pow10(fractionDigits);

  String format(int minorUnits, {bool withSymbol = true, bool signed = false}) {
    final value = _toMajor(minorUnits.abs());
    var text = _nf.format(value);
    if (digitFormat == DigitFormat.arabic) {
      text = _toArabicDigits(text);
    }
    final symbol = withSymbol ? ' $currencyCode' : '';
    if (signed) {
      final sign = minorUnits < 0 ? '-' : '+';
      return '$sign$text$symbol';
    }
    if (minorUnits < 0) return '-$text$symbol';
    return '$text$symbol';
  }

  /// Parse a user-entered string into minor units. Accepts both Arabic and
  /// Latin digits and a decimal separator (. or ,).
  int? parseMinor(String input) {
    if (input.trim().isEmpty) return null;
    var normalized = _fromArabicDigits(input).replaceAll(',', '.').trim();
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * _pow10(fractionDigits)).round();
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static String _toArabicDigits(String input) {
    final buf = StringBuffer();
    for (final ch in input.runes) {
      if (ch >= 0x30 && ch <= 0x39) {
        buf.write(_arabicDigits[ch - 0x30]);
      } else {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }

  static String _fromArabicDigits(String input) {
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
