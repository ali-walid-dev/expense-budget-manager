/// Locale-independent encoding of money amounts for CSV / XLSX export & import.
///
/// Amounts are stored as integer minor units (e.g. piastres / cents). For data
/// files we always use a `.` decimal separator and a fixed number of fraction
/// digits, so round-trips are lossless and the file opens correctly in Excel
/// and Google Sheets regardless of the device locale.
///
/// This is intentionally independent of [MoneyFormatter], which is for *display*
/// (currency symbol, grouping, Arabic digits). Files must never carry any of
/// that — see Bug 4 / Feature 7.
class AmountCodec {
  const AmountCodec._();

  /// Minor units -> canonical decimal string. `5500 -> "55.00"`,
  /// `100075 -> "1000.75"`, `-1250 -> "-12.50"`.
  static String encode(int minorUnits, {int fractionDigits = 2}) {
    final negative = minorUnits < 0;
    final abs = minorUnits.abs();
    final divisor = _pow10(fractionDigits);
    final whole = abs ~/ divisor;
    if (fractionDigits == 0) return '${negative ? '-' : ''}$whole';
    final frac = (abs % divisor).toString().padLeft(fractionDigits, '0');
    return '${negative ? '-' : ''}$whole.$frac';
  }

  /// Parses a decimal string back into minor units. Mirrors [encode] for the
  /// canonical form (`"55.00" -> 5500`) but is also tolerant of human files:
  /// accepts Arabic-Indic digits, surrounding whitespace, a `,` decimal
  /// separator, and `,`/`.` thousands separators. Returns `null` for input
  /// that isn't a valid number so callers can report a row-level error.
  ///
  /// Computed with integer math (no float rounding) so it is exactly lossless
  /// for any value [encode] can produce.
  static int? decode(String input, {int fractionDigits = 2}) {
    var s = _normalizeDigits(input).trim();
    if (s.isEmpty) return null;

    var negative = false;
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1).trim();
    } else if (s.startsWith('+')) {
      s = s.substring(1).trim();
    }
    s = s.replaceAll(' ', '');
    if (s.isEmpty) return null;

    final hasDot = s.contains('.');
    final hasComma = s.contains(',');
    if (hasDot && hasComma) {
      // The right-most separator is the decimal point; the other groups digits.
      if (s.lastIndexOf('.') > s.lastIndexOf(',')) {
        s = s.replaceAll(',', '');
      } else {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (hasComma) {
      // Lone comma: treat as the decimal separator.
      s = s.replaceAll(',', '.');
    }

    final parts = s.split('.');
    if (parts.length > 2) return null;
    final wholeStr = parts[0].isEmpty ? '0' : parts[0];
    final fracStr = parts.length == 2 ? parts[1] : '';
    if (!_isDigits(wholeStr) || (fracStr.isNotEmpty && !_isDigits(fracStr))) {
      return null;
    }

    final whole = int.parse(wholeStr);
    // Pad/truncate the fractional part to exactly [fractionDigits], rounding
    // the discarded digit so e.g. "1.005" -> 101 at 2 digits.
    var fracDigits = fracStr;
    var carry = 0;
    if (fracDigits.length > fractionDigits) {
      final roundDigit = fracDigits.codeUnitAt(fractionDigits) - 0x30;
      fracDigits = fracDigits.substring(0, fractionDigits);
      if (roundDigit >= 5) carry = 1;
    } else {
      fracDigits = fracDigits.padRight(fractionDigits, '0');
    }
    final frac = fractionDigits == 0
        ? 0
        : (fracDigits.isEmpty ? 0 : int.parse(fracDigits));
    final minor = whole * _pow10(fractionDigits) + frac + carry;
    return negative ? -minor : minor;
  }

  static bool _isDigits(String s) {
    if (s.isEmpty) return false;
    for (final c in s.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// Converts Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits to
  /// Latin so files written on Arabic devices still parse.
  static String _normalizeDigits(String input) {
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
