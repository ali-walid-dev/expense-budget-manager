import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/backup/backup_codec.dart';
import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/data/backup/local_backup_repository.dart';
import 'package:expense_budget_manager/data/backup/settings_snapshot.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

import 'db_snapshot_test.dart' show seedRichData;

/// Same-isolate stand-in for `compute` — deterministic in tests.
Future<R> syncCompute<Q, R>(ComputeCallback<Q, R> cb, Q message) async =>
    cb(message);

class FakeSettingsStore implements SettingsSnapshotStore {
  FakeSettingsStore([this.data = const {'currency': 'EGP', 'languageTag': 'ar'}]);
  Map<String, Object?> data;
  Map<String, Object?>? applied;

  @override
  Future<Map<String, Object?>> dump() async => data;

  @override
  Future<void> apply(Map<String, Object?> incoming) async => applied = incoming;
}

Future<int> count(AppDatabase db, String table) async {
  final r =
      await db.customSelect('SELECT COUNT(*) AS c FROM "$table"').getSingle();
  return r.read<int>('c');
}

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late FakeSettingsStore sourceSettings;
  late FakeSettingsStore targetSettings;

  LocalBackupRepository repoFor(AppDatabase db, SettingsSnapshotStore store) =>
      LocalBackupRepositoryImpl(
        db: db,
        settingsStore: store,
        appVersion: () async => '1.2.3',
        compute: syncCompute,
      );

  setUp(() {
    source = AppDatabase.connect(NativeDatabase.memory());
    target = AppDatabase.connect(NativeDatabase.memory());
    sourceSettings = FakeSettingsStore({'currency': 'USD', 'languageTag': 'en'});
    targetSettings = FakeSettingsStore();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('exported bytes decode back into the full dataset', () async {
    await seedRichData(source);
    final expected = await dumpDatabase(source);

    final bytes = await repoFor(source, sourceSettings).exportBytes();
    final doc = await repoFor(target, targetSettings).read(bytes);

    expect(doc.appVersion, '1.2.3');
    for (final table in kBackupTables) {
      expect(doc.tables[table], hasLength(expected[table]!.length),
          reason: 'table "$table" did not survive the round trip');
    }
    expect(doc.settings['currency'], 'USD');
  });

  test('exporting then importing onto a clean device reproduces the data',
      () async {
    await seedRichData(source);

    final bytes = await repoFor(source, sourceSettings).exportBytes();
    final targetRepo = repoFor(target, targetSettings);
    await targetRepo.merge(await targetRepo.read(bytes));

    expect(await count(target, 'transactions'), 5);
    expect(await count(target, 'categories'), 3);
    expect(await count(target, 'debts'), 1);
    expect(await count(target, 'budgets'), 1);
  });

  test('merge leaves device settings alone unless asked', () async {
    await seedRichData(source);
    final bytes = await repoFor(source, sourceSettings).exportBytes();
    final targetRepo = repoFor(target, targetSettings);

    await targetRepo.merge(await targetRepo.read(bytes));

    expect(targetSettings.applied, isNull,
        reason: 'importing data must not silently change language/currency');
  });

  test('merge applies the exported settings when explicitly asked', () async {
    await seedRichData(source);
    final bytes = await repoFor(source, sourceSettings).exportBytes();
    final targetRepo = repoFor(target, targetSettings);

    await targetRepo.merge(await targetRepo.read(bytes), applySettings: true);

    expect(targetSettings.applied?['currency'], 'USD');
  });

  test('replaceAll wipes local data and applies the exported settings',
      () async {
    await seedRichData(source);
    await target.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (99, 'Stale', 'cash')");
    final bytes = await repoFor(source, sourceSettings).exportBytes();
    final targetRepo = repoFor(target, targetSettings);

    await targetRepo.replaceAll(await targetRepo.read(bytes));

    final names = (await target.customSelect('SELECT name FROM accounts').get())
        .map((r) => r.read<String>('name'));
    expect(names, isNot(contains('Stale')));
    expect(targetSettings.applied?['currency'], 'USD');
  });

  test('a file from a newer app version is refused before any data changes',
      () async {
    await seedRichData(source);
    final repo = repoFor(target, targetSettings);
    final doc = await repo.read(await repoFor(source, sourceSettings).exportBytes());
    final fromTheFuture = BackupDocument(
      envelopeVersion: doc.envelopeVersion,
      appVersion: doc.appVersion,
      createdAt: doc.createdAt,
      deviceInfo: doc.deviceInfo,
      dbSchemaVersion: target.schemaVersion + 1,
      tables: doc.tables,
      settings: doc.settings,
    );

    await expectLater(
        repo.merge(fromTheFuture), throwsA(isA<UnsupportedVersionFailure>()));
    expect(await count(target, 'transactions'), 0);
  });

  test('a corrupt file is rejected with a typed failure', () async {
    final repo = repoFor(target, targetSettings);

    await expectLater(repo.read(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<CorruptBackupFailure>()));
  });

  test('the import preview reports what the file holds', () async {
    await seedRichData(source);
    final repo = repoFor(target, targetSettings);

    final doc = await repo.read(await repoFor(source, sourceSettings).exportBytes());
    final preview = repo.preview(doc);

    expect(preview.appVersion, '1.2.3');
    expect(preview.counts['transactions'], 5);
    expect(preview.counts['accounts'], 2);
  });
}
