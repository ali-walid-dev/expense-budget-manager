import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' as foundation;

import 'package:expense_budget_manager/data/backup/backup_codec.dart';
import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/data/backup/merge_snapshot.dart';
import 'package:expense_budget_manager/data/backup/settings_snapshot.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// What an import file holds, shown to the user before anything is applied.
class ImportPreview {
  const ImportPreview({
    required this.appVersion,
    required this.createdAt,
    required this.counts,
  });

  final String appVersion;
  final DateTime createdAt;

  /// Row count per table, as found in the file.
  final Map<String, int> counts;

  int get transactionCount => counts['transactions'] ?? 0;
}

/// Export to / import from a plain file, using exactly the same envelope as
/// the Google Drive backup — a file exported here can be restored from Drive
/// and vice versa.
abstract class LocalBackupRepository {
  /// The full dataset as a gzip-compressed backup document.
  Future<Uint8List> exportBytes();

  /// Parses and validates [bytes]. Throws [CorruptBackupFailure] or
  /// [UnsupportedVersionFailure]; never touches the database.
  Future<BackupDocument> read(Uint8List bytes);

  /// What [doc] contains, for the confirmation dialog.
  ImportPreview preview(BackupDocument doc);

  /// Adds everything missing, keeping local data. App settings are left alone
  /// unless [applySettings] is set — language, theme and currency are live
  /// preferences, not rows to be filled in.
  Future<MergeReport> merge(BackupDocument doc, {bool applySettings = false});

  /// Replaces all local data with [doc], atomically.
  Future<void> replaceAll(BackupDocument doc);
}

class LocalBackupRepositoryImpl implements LocalBackupRepository {
  LocalBackupRepositoryImpl({
    required this.db,
    required this.settingsStore,
    Future<String> Function()? appVersion,
    Future<R> Function<Q, R>(foundation.ComputeCallback<Q, R>, Q)? compute,
  })  : _appVersion = appVersion ?? (() async => 'unknown'),
        _compute = compute ?? _defaultCompute;

  final AppDatabase db;
  final SettingsSnapshotStore settingsStore;
  final Future<String> Function() _appVersion;
  final Future<R> Function<Q, R>(foundation.ComputeCallback<Q, R>, Q) _compute;

  static Future<R> _defaultCompute<Q, R>(
          foundation.ComputeCallback<Q, R> cb, Q message) =>
      foundation.compute(cb, message);

  @override
  Future<Uint8List> exportBytes() async {
    final tables = await dumpDatabase(db);
    final settings = await settingsStore.dump();
    final envelope = buildEnvelope(
      tables: tables,
      settings: settings,
      dbSchemaVersion: db.schemaVersion,
      appVersion: await _appVersion(),
      deviceInfo: _deviceInfo(),
      createdAtUtc: DateTime.now().toUtc(),
    );
    // Off the main isolate: a long history must not jank the UI.
    return _compute(encodeBackupBytes, envelope);
  }

  @override
  Future<BackupDocument> read(Uint8List bytes) =>
      _compute(decodeBackupBytes, bytes);

  @override
  ImportPreview preview(BackupDocument doc) => ImportPreview(
        appVersion: doc.appVersion,
        createdAt: doc.createdAt,
        counts: {
          for (final entry in doc.tables.entries) entry.key: entry.value.length,
        },
      );

  @override
  Future<MergeReport> merge(BackupDocument doc,
      {bool applySettings = false}) async {
    _rejectNewerSchema(doc);
    final report = await mergeDatabase(db, doc.tables);
    if (applySettings) await settingsStore.apply(doc.settings);
    return report;
  }

  @override
  Future<void> replaceAll(BackupDocument doc) async {
    _rejectNewerSchema(doc);
    await restoreDatabase(db, doc.tables);
    // Settings only after the DB commit succeeded.
    await settingsStore.apply(doc.settings);
  }

  /// Data written by a newer app may carry columns or semantics this build
  /// does not understand — refuse before touching anything.
  void _rejectNewerSchema(BackupDocument doc) {
    if (doc.dbSchemaVersion > db.schemaVersion) {
      throw UnsupportedVersionFailure(
          found: doc.dbSchemaVersion, supported: db.schemaVersion);
    }
  }

  String _deviceInfo() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } on Object {
      return 'unknown';
    }
  }
}
