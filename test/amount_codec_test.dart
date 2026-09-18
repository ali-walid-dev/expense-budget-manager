import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/core/common/amount_codec.dart';

void main() {
  group('AmountCodec.encode', () {
    test('formats minor units with a fixed decimal point', () {
      expect(AmountCodec.encode(5500), '55.00');
      expect(AmountCodec.encode(12550), '125.50');
      expect(AmountCodec.encode(100075), '1000.75');
      expect(AmountCodec.encode(0), '0.00');
      expect(AmountCodec.encode(5), '0.05');
      expect(AmountCodec.encode(-1250), '-12.50');
    });

    test('never emits a comma or thousands separator', () {
      expect(AmountCodec.encode(123456789), '1234567.89');
    });
  });

  group('AmountCodec.decode', () {
    test('parses the canonical form exactly', () {
      expect(AmountCodec.decode('55.00'), 5500);
      expect(AmountCodec.decode('125.50'), 12550);
      expect(AmountCodec.decode('1000.75'), 100075);
      expect(AmountCodec.decode('-12.50'), -1250);
      expect(AmountCodec.decode('0.05'), 5);
    });

    test('tolerates comma decimal separators and thousands grouping', () {
      expect(AmountCodec.decode('55,00'), 5500);
      expect(AmountCodec.decode('1,000.75'), 100075);
      expect(AmountCodec.decode('1.000,75'), 100075);
      expect(AmountCodec.decode(' 125.50 '), 12550);
    });

    test('parses Arabic-Indic digits', () {
      expect(AmountCodec.decode('٥٥.٠٠'), 5500);
    });

    test('rounds excess fraction digits', () {
      expect(AmountCodec.decode('1.005'), 101);
      expect(AmountCodec.decode('1.004'), 100);
    });

    test('returns null for invalid input', () {
      expect(AmountCodec.decode(''), isNull);
      expect(AmountCodec.decode('abc'), isNull);
      expect(AmountCodec.decode('1.2.3'), isNull);
    });
  });

  group('round-trip', () {
    test('encode -> decode is lossless', () {
      for (final v in [0, 5, 5500, 12550, 100075, 999999, -1250]) {
        expect(AmountCodec.decode(AmountCodec.encode(v)), v);
      }
    });
  });
}
