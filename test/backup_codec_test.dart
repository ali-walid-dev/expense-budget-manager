import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/backup/backup_codec.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// Structurally-valid gzip wrapping arbitrary JSON text — for testing decode
/// of well-compressed but semantically invalid documents.
Uint8List gzipJson(String json) =>
    Uint8List.fromList(gzip.encode(utf8.encode(json)));

void main() {
  final tables = <String, List<Map<String, Object?>>>{
    'accounts': [
      {'id': 1, 'name': 'Cash', 'type': 'cash', 'initial_balance': 1000},
    ],
    'categories': [
      {'id': 1, 'name': 'Food', 'parent_id': null, 'type': 'expense'},
      {'id': 2, 'name': 'Coffee', 'parent_id': 1, 'type': 'expense'},
    ],
    'transactions': [
      {
        'id': 1,
        'amount': 5500,
        'type': 'expense',
        'category_id': 2,
        'account_id': 1,
        'date_time': 1700000000000,
        'note': 'لاتيه - latte', // Arabic survives the round-trip
        'latitude': 30.05,
      },
    ],
  };
  final settings = <String, Object?>{
    'languageTag': 'ar',
    'currency': 'EGP',
    'weekStartDay': 6,
    'onboarded': true,
  };

  Map<String, Object?> envelope() => buildEnvelope(
        tables: tables,
        settings: settings,
        dbSchemaVersion: 3,
        appVersion: '1.2.3+4',
        deviceInfo: 'test os',
        createdAtUtc: DateTime.utc(2026, 6, 12, 10, 30),
      );

  group('envelope', () {
    test('has the required structure', () {
      final e = envelope();
      expect(e['schemaVersion'], kBackupEnvelopeVersion);
      expect(e['appVersion'], '1.2.3+4');
      expect(e['createdAt'], '2026-06-12T10:30:00.000Z');
      final data = e['data'] as Map<String, Object?>;
      expect(data['dbSchemaVersion'], 3);
      expect(data['transactions'], isA<List<Object?>>());
      final config = data['configurations'] as Map<String, Object?>;
      expect(config.containsKey('accounts'), isTrue);
      expect(config.containsKey('transactions'), isFalse);
      expect(data['settings'], settings);
    });
  });

  group('encode/decode round-trip', () {
    test('is lossless for tables and settings', () {
      final bytes = encodeBackupBytes(envelope());
      final doc = decodeBackupBytes(bytes);

      expect(doc.envelopeVersion, kBackupEnvelopeVersion);
      expect(doc.appVersion, '1.2.3+4');
      expect(doc.dbSchemaVersion, 3);
      expect(doc.createdAt, DateTime.utc(2026, 6, 12, 10, 30));

      const eq = DeepCollectionEquality();
      expect(eq.equals(doc.tables['transactions'], tables['transactions']),
          isTrue);
      expect(eq.equals(doc.tables['accounts'], tables['accounts']), isTrue);
      expect(eq.equals(doc.tables['categories'], tables['categories']), isTrue);
      expect(eq.equals(doc.settings, settings), isTrue);
    });

    test('output is gzip-compressed', () {
      final e = {
        ...envelope(),
        'padding': List.generate(500, (i) => 'repeated text block ' * 10),
      };
      final raw = utf8.encode(jsonEncode(e)).length;
      final compressed = encodeBackupBytes(e).length;
      expect(compressed, lessThan(raw ~/ 4));
    });
  });

  group('corruption handling', () {
    test('garbage bytes -> CorruptBackupFailure', () {
      expect(() => decodeBackupBytes(Uint8List.fromList([1, 2, 3, 4, 5])),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('truncated gzip -> CorruptBackupFailure', () {
      final good = encodeBackupBytes(envelope());
      final truncated = Uint8List.sublistView(good, 0, good.length ~/ 2);
      expect(() => decodeBackupBytes(truncated),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('valid gzip of a non-object -> CorruptBackupFailure', () {
      expect(() => decodeBackupBytes(gzipJson('[1,2,3]')),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('missing schemaVersion -> CorruptBackupFailure', () {
      final e = envelope()..remove('schemaVersion');
      expect(() => decodeBackupBytes(encodeBackupBytes(e)),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('missing data -> CorruptBackupFailure', () {
      final e = envelope()..remove('data');
      expect(() => decodeBackupBytes(encodeBackupBytes(e)),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('transactions not a list -> CorruptBackupFailure', () {
      final e = envelope();
      (e['data'] as Map<String, Object?>)['transactions'] = 'oops';
      expect(() => decodeBackupBytes(encodeBackupBytes(e)),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('row that is not an object -> CorruptBackupFailure', () {
      final e = envelope();
      (e['data'] as Map<String, Object?>)['transactions'] = [1, 2];
      expect(() => decodeBackupBytes(encodeBackupBytes(e)),
          throwsA(isA<CorruptBackupFailure>()));
    });
  });

  group('versioning', () {
    test('newer envelope -> UnsupportedVersionFailure with versions', () {
      final e = envelope()..['schemaVersion'] = kBackupEnvelopeVersion + 1;
      expect(
        () => decodeBackupBytes(encodeBackupBytes(e)),
        throwsA(isA<UnsupportedVersionFailure>()
            .having((f) => f.found, 'found', kBackupEnvelopeVersion + 1)
            .having((f) => f.supported, 'supported', kBackupEnvelopeVersion)),
      );
    });

    test('invalid version 0 -> CorruptBackupFailure', () {
      final e = envelope()..['schemaVersion'] = 0;
      expect(() => decodeBackupBytes(encodeBackupBytes(e)),
          throwsA(isA<CorruptBackupFailure>()));
    });

    test('migrateEnvelope passes the current version through unchanged', () {
      final e = envelope();
      expect(identical(migrateEnvelope(e), e), isTrue);
    });
  });
}
