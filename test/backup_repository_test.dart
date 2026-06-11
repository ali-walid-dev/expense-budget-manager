import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_budget_manager/data/backup/backup_codec.dart';
import 'package:expense_budget_manager/data/backup/backup_preferences.dart';
import 'package:expense_budget_manager/data/backup/backup_repository_impl.dart';
import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/data/backup/settings_snapshot.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';
import 'package:expense_budget_manager/domain/backup/backup_repository.dart';
import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';

import 'db_snapshot_test.dart' show seedRichData;

/// Same-isolate stand-in for `compute` — deterministic in tests.
Future<R> syncCompute<Q, R>(ComputeCallback<Q, R> cb, Q message) async =>
    cb(message);

class FakeAuthService implements AuthService {
  AuthUser? user = const AuthUser(id: 'acc-1', email: 'a@example.com');

  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() => const Stream.empty();
  @override
  Future<AuthUser?> signIn() async => user;
  @override
  Future<AuthUser?> signInSilently() async => user;
  @override
  Future<void> signOut() async => user = null;
  @override
  Future<void> disconnect() async => user = null;
}

class InMemoryDriveClient implements DriveBackupClient {
  final files = <String, Uint8List>{};
  final meta = <String, RemoteBackup>{};
  int _seq = 0;

  @override
  Future<List<RemoteBackup>> list() async {
    final all = meta.values.toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return all;
  }

  @override
  Future<RemoteBackup> upload(
      {required String name, required Uint8List bytes}) async {
    _seq++;
    final id = 'file-$_seq';
    files[id] = bytes;
    final info = RemoteBackup(
      id: id,
      name: name,
      // Strictly increasing synthetic clock — stable ordering.
      createdAt: DateTime.utc(2030).add(Duration(minutes: _seq)),
      sizeBytes: bytes.length,
    );
    meta[id] = info;
    return info;
  }

  @override
  Future<Uint8List> download(String id) async {
    final bytes = files[id];
    if (bytes == null) throw const NoBackupFailure();
    return bytes;
  }

  @override
  Future<void> delete(String id) async {
    files.remove(id);
    meta.remove(id);
  }
}

class InMemorySettingsStore implements SettingsSnapshotStore {
  Map<String, Object?> current = {
    'languageTag': 'ar',
    'themeMode': 'dark',
    'currency': 'EGP',
    'weekStartDay': 6,
    'budgetStartDay': 1,
    'digitFormat': 'arabic',
    'onboarded': true,
  };
  Map<String, Object?>? applied;

  @override
  Future<Map<String, Object?>> dump() async => Map.of(current);
  @override
  Future<void> apply(Map<String, Object?> data) async => applied = data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeAuthService auth;
  late InMemoryDriveClient drive;
  late InMemorySettingsStore settings;
  late BackupPreferences prefs;
  late BackupRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.connect(NativeDatabase.memory());
    auth = FakeAuthService();
    drive = InMemoryDriveClient();
    settings = InMemorySettingsStore();
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    repo = BackupRepositoryImpl(
      db: db,
      auth: auth,
      drive: drive,
      settingsStore: settings,
      prefs: prefs,
      appVersion: () async => '9.9.9+9',
      compute: syncCompute,
    );
  });

  tearDown(() => db.close());

  Future<void> wipeDb() async {
    for (final t in kBackupTables.reversed) {
      await db.customStatement('DELETE FROM "$t"');
    }
  }

  test('backup -> wipe -> restore reproduces the exact dataset and settings',
      () async {
    await seedRichData(db);
    final original = await dumpDatabase(db);

    final result = await repo.backupNow();
    expect(result.sizeBytes, greaterThan(0));
    expect(prefs.lastBackupAt, isNotNull);
    expect(prefs.lastBackupSizeBytes, result.sizeBytes);
    expect(prefs.boundAccountId, 'acc-1');

    await wipeDb();
    expect(await repo.localTransactionCount(), 0);

    await repo.restore();

    final restored = await dumpDatabase(db);
    expect(const DeepCollectionEquality().equals(restored, original), isTrue);
    expect(const DeepCollectionEquality().equals(settings.applied, settings.current),
        isTrue);
  });

  test('restore with no backup -> NoBackupFailure', () async {
    await expectLater(repo.restore(), throwsA(isA<NoBackupFailure>()));
  });

  test('backup requires sign-in -> AuthFailure', () async {
    auth.user = null;
    await expectLater(repo.backupNow(), throwsA(isA<AuthFailure>()));
    await expectLater(repo.restore(), throwsA(isA<AuthFailure>()));
  });

  test('corrupted cloud file -> CorruptBackupFailure, local data untouched',
      () async {
    await seedRichData(db);
    await repo.backupNow();
    final before = await dumpDatabase(db);

    // Corrupt the newest stored blob.
    final newest = (await drive.list()).first;
    drive.files[newest.id] = Uint8List.fromList([0, 1, 2, 3]);

    await expectLater(repo.restore(), throwsA(isA<CorruptBackupFailure>()));
    final after = await dumpDatabase(db);
    expect(const DeepCollectionEquality().equals(after, before), isTrue);
    expect(settings.applied, isNull,
        reason: 'settings must not be applied when the restore failed');
  });

  test('backup from a newer DB schema -> UnsupportedVersionFailure', () async {
    final envelope = buildEnvelope(
      tables: const {'transactions': []},
      settings: const {},
      dbSchemaVersion: 99,
      appVersion: 'future',
      deviceInfo: 'future device',
      createdAtUtc: DateTime.utc(2031),
    );
    await drive.upload(
        name: 'backup_future.json.gz', bytes: encodeBackupBytes(envelope));

    await expectLater(
        repo.restore(), throwsA(isA<UnsupportedVersionFailure>()));
  });

  test('keeps only the newest $kKeptBackups backups (pruning)', () async {
    await seedRichData(db);
    for (var i = 0; i < 5; i++) {
      await repo.backupNow();
    }
    expect(drive.files.length, kKeptBackups);
    // The survivors are the newest ones.
    final names = (await drive.list()).map((b) => b.id).toList();
    expect(names, ['file-5', 'file-4', 'file-3']);
  });

  group('checkAfterSignIn', () {
    test('no cloud backup -> none', () async {
      expect(await repo.checkAfterSignIn(), isA<PostSignInNone>());
    });

    test('empty device + backup exists -> prompt restore (fresh install)',
        () async {
      await seedRichData(db);
      await repo.backupNow();
      await wipeDb();

      final check = await repo.checkAfterSignIn();
      expect(check, isA<PostSignInPromptRestore>());
    });

    test('local data bound to the same account -> none (normal state)',
        () async {
      await seedRichData(db);
      await repo.backupNow(); // binds acc-1
      final check = await repo.checkAfterSignIn();
      expect(check, isA<PostSignInNone>());
      expect((check as PostSignInNone).cloudBackup, isNotNull);
    });

    test('local data + different account -> explicit conflict', () async {
      await seedRichData(db);
      await repo.backupNow(); // binds acc-1
      auth.user = const AuthUser(id: 'acc-2', email: 'other@example.com');

      final check = await repo.checkAfterSignIn();
      expect(check, isA<PostSignInConflict>());
      final conflict = check as PostSignInConflict;
      expect(conflict.localTransactionCount, greaterThan(0));
    });
  });
}
