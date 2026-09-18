import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' as foundation;

import 'package:expense_budget_manager/data/backup/backup_cipher.dart';
import 'package:expense_budget_manager/data/backup/backup_codec.dart';
import 'package:expense_budget_manager/data/backup/backup_preferences.dart';
import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/data/backup/settings_snapshot.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';
import 'package:expense_budget_manager/domain/backup/backup_repository.dart';
import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';

/// How many timestamped backups to keep in appDataFolder. New uploads never
/// overwrite in place — the previous N backups survive a corrupted upload.
const kKeptBackups = 3;

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl({
    required this.db,
    required this.auth,
    required this.drive,
    required this.settingsStore,
    required this.prefs,
    this.cipher = const NoopBackupCipher(),
    Future<String> Function()? appVersion,
    Future<R> Function<Q, R>(foundation.ComputeCallback<Q, R>, Q)? compute,
  })  : _appVersion = appVersion ?? (() async => 'unknown'),
        _compute = compute ?? _defaultCompute;

  final AppDatabase db;
  final AuthService auth;
  final DriveBackupClient drive;
  final SettingsSnapshotStore settingsStore;
  final BackupPreferences prefs;
  final BackupCipher cipher;
  final Future<String> Function() _appVersion;
  final Future<R> Function<Q, R>(foundation.ComputeCallback<Q, R>, Q) _compute;

  static Future<R> _defaultCompute<Q, R>(
          foundation.ComputeCallback<Q, R> cb, Q message) =>
      foundation.compute(cb, message);

  @override
  Future<BackupResult> backupNow() async {
    final user = auth.currentUser;
    if (user == null) throw const AuthFailure('not signed in');

    final tables = await dumpDatabase(db);
    final settings = await settingsStore.dump();
    final now = DateTime.now().toUtc();
    final envelope = buildEnvelope(
      tables: tables,
      settings: settings,
      dbSchemaVersion: db.schemaVersion,
      appVersion: await _appVersion(),
      deviceInfo: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      createdAtUtc: now,
    );

    // Serialization + gzip off the main isolate so 10k+ transactions never
    // freeze the UI.
    final gz = await _compute(encodeBackupBytes, envelope);
    final bytes = await cipher.encrypt(gz);

    final stamp = now.toIso8601String().replaceAll(':', '-');
    await drive.upload(name: 'backup_$stamp.json.gz', bytes: bytes);
    await _prune();

    await prefs.setLastBackup(now.toLocal(), bytes.length);
    await prefs.bindAccount(user.id);
    return BackupResult(createdAt: now, sizeBytes: bytes.length);
  }

  @override
  Future<RemoteBackup?> latestCloudBackup() async {
    final all = await drive.list();
    return all.isEmpty ? null : all.first;
  }

  @override
  Future<void> restore({RemoteBackup? from}) async {
    final user = auth.currentUser;
    if (user == null) throw const AuthFailure('not signed in');

    final target = from ?? await latestCloudBackup();
    if (target == null) throw const NoBackupFailure();

    final raw = await drive.download(target.id);
    final gz = await cipher.decrypt(raw);

    // Decode + validate + migrate off the main isolate. Throws typed failures
    // for corruption / unsupported versions BEFORE anything touches the DB.
    final doc = await _compute(decodeBackupBytes, Uint8List.fromList(gz));

    if (doc.dbSchemaVersion > db.schemaVersion) {
      // Data written by a newer app may contain columns/semantics we don't
      // know — refuse cleanly. (Older versions are fine: inserts use explicit
      // column lists, so missing columns take their SQL defaults.)
      throw UnsupportedVersionFailure(
          found: doc.dbSchemaVersion, supported: db.schemaVersion);
    }

    // Single transaction: any failure rolls back, local data stays intact.
    await restoreDatabase(db, doc.tables);

    // Settings only after the DB commit succeeded (atomicity of the risky
    // part; settings application is idempotent).
    await settingsStore.apply(doc.settings);

    await prefs.bindAccount(user.id);
  }

  @override
  Future<int> localTransactionCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM transactions')
        .getSingle();
    return row.read<int>('c');
  }

  @override
  Future<PostSignInCheck> checkAfterSignIn() async {
    final user = auth.currentUser;
    if (user == null) throw const AuthFailure('not signed in');

    final cloud = await latestCloudBackup();
    if (cloud == null) return const PostSignInNone();

    final localCount = await localTransactionCount();
    if (localCount == 0) return PostSignInPromptRestore(cloud);

    // Local data exists. Same account as the data is bound to -> normal
    // ongoing state. Different (or unknown) account -> explicit conflict.
    if (prefs.boundAccountId == user.id) {
      return PostSignInNone(cloudBackup: cloud);
    }
    return PostSignInConflict(
        cloudBackup: cloud, localTransactionCount: localCount);
  }

  Future<void> _prune() async {
    final all = await drive.list();
    for (final old in all.skip(kKeptBackups)) {
      try {
        await drive.delete(old.id);
      } on BackupFailure {
        // Pruning is best-effort; a leftover old backup is harmless.
      }
    }
  }
}
