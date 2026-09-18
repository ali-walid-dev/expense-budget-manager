import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// Version of the backup *envelope* (independent of the DB schema version,
/// which travels inside the payload as `data.dbSchemaVersion`).
const kBackupEnvelopeVersion = 1;

/// A parsed, validated, migrated-to-current backup document.
class BackupDocument {
  const BackupDocument({
    required this.envelopeVersion,
    required this.appVersion,
    required this.createdAt,
    required this.deviceInfo,
    required this.dbSchemaVersion,
    required this.tables,
    required this.settings,
  });

  final int envelopeVersion;
  final String appVersion;
  final DateTime createdAt;
  final String deviceInfo;
  final int dbSchemaVersion;
  final DbSnapshot tables;
  final Map<String, Object?> settings;
}

/// Builds the JSON envelope. `transactions` ride at the top of `data` per the
/// backup contract; every other table is grouped under `configurations`.
Map<String, Object?> buildEnvelope({
  required DbSnapshot tables,
  required Map<String, Object?> settings,
  required int dbSchemaVersion,
  required String appVersion,
  required String deviceInfo,
  required DateTime createdAtUtc,
}) {
  final configurations = <String, Object?>{
    for (final t in kBackupTables)
      if (t != 'transactions') t: tables[t] ?? const [],
  };
  return {
    'schemaVersion': kBackupEnvelopeVersion,
    'appVersion': appVersion,
    'createdAt': createdAtUtc.toUtc().toIso8601String(),
    'deviceInfo': deviceInfo,
    'data': {
      'dbSchemaVersion': dbSchemaVersion,
      'transactions': tables['transactions'] ?? const [],
      'configurations': configurations,
      'settings': settings,
    },
  };
}

/// JSON-encode + gzip. Top-level function so it can run via `compute` off the
/// main isolate (large histories must never jank the UI).
Uint8List encodeBackupBytes(Map<String, Object?> envelope) {
  final jsonBytes = utf8.encode(jsonEncode(envelope));
  return Uint8List.fromList(gzip.encode(jsonBytes));
}

/// Gunzip + JSON-decode + validate + migrate. Top-level for `compute`. Any
/// structural problem throws [CorruptBackupFailure]; a newer envelope throws
/// [UnsupportedVersionFailure]. Never partially succeeds.
BackupDocument decodeBackupBytes(Uint8List bytes) {
  final Object? root;
  try {
    root = jsonDecode(utf8.decode(gzip.decode(bytes)));
  } on Exception catch (e) {
    throw CorruptBackupFailure('not a gzip/json document: $e');
  }
  if (root is! Map<String, Object?>) {
    throw CorruptBackupFailure('root is not an object');
  }
  final migrated = migrateEnvelope(root);
  return _parseCurrentEnvelope(migrated);
}

/// Upgrades older envelope versions to [kBackupEnvelopeVersion]. v1 is the
/// first version, so this is currently a validation gate + the dispatch point
/// for future migrations (v1 -> v2 would be added here).
Map<String, Object?> migrateEnvelope(Map<String, Object?> envelope) {
  final v = envelope['schemaVersion'];
  if (v is! int) throw const CorruptBackupFailure('missing schemaVersion');
  if (v > kBackupEnvelopeVersion) {
    throw UnsupportedVersionFailure(found: v, supported: kBackupEnvelopeVersion);
  }
  if (v < 1) throw CorruptBackupFailure('invalid schemaVersion $v');

  var current = envelope;
  // Future: if (v == 1) { current = _v1ToV2(current); }
  return current;
}

BackupDocument _parseCurrentEnvelope(Map<String, Object?> e) {
  final data = e['data'];
  if (data is! Map<String, Object?>) {
    throw const CorruptBackupFailure('missing data');
  }
  final dbVersion = data['dbSchemaVersion'];
  if (dbVersion is! int) {
    throw const CorruptBackupFailure('missing data.dbSchemaVersion');
  }
  final transactions = data['transactions'];
  final configurations = data['configurations'];
  final settings = data['settings'];
  if (transactions is! List || configurations is! Map<String, Object?>) {
    throw const CorruptBackupFailure('missing transactions/configurations');
  }
  if (settings is! Map<String, Object?>) {
    throw const CorruptBackupFailure('missing settings');
  }

  final tables = <String, List<Map<String, Object?>>>{
    'transactions': _rowList('transactions', transactions),
    for (final entry in configurations.entries)
      entry.key: _rowList(entry.key, entry.value),
  };

  final createdAtRaw = e['createdAt'];
  final createdAt =
      createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null;

  return BackupDocument(
    envelopeVersion: e['schemaVersion'] as int,
    appVersion: e['appVersion'] as String? ?? 'unknown',
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    deviceInfo: e['deviceInfo'] as String? ?? 'unknown',
    dbSchemaVersion: dbVersion,
    tables: tables,
    settings: settings,
  );
}

List<Map<String, Object?>> _rowList(String table, Object? value) {
  if (value is! List) {
    throw CorruptBackupFailure('table "$table" is not a list');
  }
  return value.map((row) {
    if (row is! Map<String, Object?>) {
      throw CorruptBackupFailure('row in "$table" is not an object');
    }
    return Map<String, Object?>.from(row);
  }).toList();
}
