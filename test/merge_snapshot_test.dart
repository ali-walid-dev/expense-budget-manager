import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/backup/db_snapshot.dart';
import 'package:expense_budget_manager/data/backup/merge_snapshot.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';

import 'db_snapshot_test.dart' show seedRichData;

Future<List<Map<String, Object?>>> rows(AppDatabase db, String table) async {
  final r = await db.customSelect('SELECT * FROM "$table" ORDER BY id').get();
  return r.map((e) => Map<String, Object?>.from(e.data)).toList();
}

Future<int> count(AppDatabase db, String table) async {
  final r =
      await db.customSelect('SELECT COUNT(*) AS c FROM "$table"').getSingle();
  return r.read<int>('c');
}

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase.connect(NativeDatabase.memory());
    target = AppDatabase.connect(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('merging into an empty database inserts every row', () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);

    await mergeDatabase(target, snapshot);

    for (final table in kBackupTables) {
      expect(await count(target, table), snapshot[table]!.length,
          reason: 'row count mismatch for "$table"');
    }
  });

  test('merge rewrites foreign keys to the ids assigned in the target',
      () async {
    await seedRichData(source);
    // Occupy the low ids in the target so a naive copy would collide and a
    // non-remapping merge would silently attach rows to the wrong parents.
    await target.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (1, 'Unrelated', 'cash')");
    await target.customStatement(
        "INSERT INTO categories (id, name, parent_id, type) "
        "VALUES (1, 'Unrelated', NULL, 'expense')");

    await mergeDatabase(target, await dumpDatabase(source));

    // 'مطاعم' is a child of 'Food' in the source; the link must survive.
    final categories = await rows(target, 'categories');
    final food = categories.firstWhere((c) => c['name'] == 'Food');
    final restaurants = categories.firstWhere((c) => c['name'] == 'مطاعم');
    expect(restaurants['parent_id'], food['id']);
    expect(food['id'], isNot(1), reason: 'id 1 was already taken');

    // The 5500 lunch transaction belongs to 'مطاعم' on the 'Cash' account.
    final accounts = await rows(target, 'accounts');
    final cash = accounts.firstWhere((a) => a['name'] == 'Cash');
    final lunch =
        (await rows(target, 'transactions')).firstWhere((t) => t['amount'] == 5500);
    expect(lunch['category_id'], restaurants['id']);
    expect(lunch['account_id'], cash['id']);
  });

  test('merging the same snapshot twice adds nothing the second time',
      () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);

    await mergeDatabase(target, snapshot);
    final afterFirst = {
      for (final t in kBackupTables) t: await count(target, t),
    };

    final report = await mergeDatabase(target, snapshot);

    for (final table in kBackupTables) {
      expect(await count(target, table), afterFirst[table],
          reason: 'second merge duplicated rows in "$table"');
    }
    expect(report.inserted.values.fold<int>(0, (a, b) => a + b), 0);
    expect(report.skipped['transactions'], 5);
  });

  test('merge keeps existing rows untouched', () async {
    await seedRichData(source);
    await target.customStatement(
        "INSERT INTO accounts (id, name, type, initial_balance) "
        "VALUES (7, 'Cash', 'bank', 999)");

    await mergeDatabase(target, await dumpDatabase(source));

    final cash = (await rows(target, 'accounts'))
        .where((a) => a['name'] == 'Cash')
        .toList();
    expect(cash, hasLength(1), reason: 'matched by name, must not duplicate');
    expect(cash.single['id'], 7);
    expect(cash.single['initial_balance'], 999,
        reason: 'the local row wins; the incoming one is not applied');
  });

  test('merge reports what it inserted and what it skipped', () async {
    await seedRichData(source);
    await target.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (1, 'Cash', 'cash')");

    final report = await mergeDatabase(target, await dumpDatabase(source));

    expect(report.skipped['accounts'], 1);
    expect(report.inserted['accounts'], 1); // only 'Bank' is new
    expect(report.inserted['transactions'], 5);
  });

  test('a transaction differing only in note is treated as new', () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);
    await mergeDatabase(target, snapshot);

    final edited = {
      for (final e in snapshot.entries) e.key: [...e.value],
    };
    edited['transactions'] = [
      {...snapshot['transactions']!.first, 'note': 'a different note'},
    ];

    final report = await mergeDatabase(target, edited);

    expect(report.inserted['transactions'], 1);
  });

  test('merge rejects an unknown table without touching the database',
      () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);
    snapshot['evil'] = [
      {'id': 1}
    ];

    await expectLater(mergeDatabase(target, snapshot), throwsA(isA<Exception>()));
    expect(await count(target, 'transactions'), 0);
  });

  test('a failure part-way through rolls the whole merge back', () async {
    await seedRichData(source);
    final snapshot = await dumpDatabase(source);
    // An unknown column is only discovered once earlier tables have already
    // been inserted — proving the rollback covers the whole operation.
    snapshot['transactions'] = [
      {...snapshot['transactions']!.first, 'bogus_column': 1},
    ];

    await expectLater(mergeDatabase(target, snapshot), throwsA(isA<Exception>()));
    expect(await count(target, 'accounts'), 0);
    expect(await count(target, 'categories'), 0);
  });
}
