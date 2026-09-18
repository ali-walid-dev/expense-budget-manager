import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/data/import/transaction_import_service.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';

void main() {
  late AppDatabase db;
  late TransactionImportService svc;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase.connect(NativeDatabase.memory());
    svc = TransactionImportService(db);
    tmp = await Directory.systemTemp.createTemp('import_test');
    await db.customStatement(
        "INSERT INTO accounts (id, name, type) VALUES (1, 'Cash', 'cash')");
    await db.customStatement(
        "INSERT INTO categories (id, name, type) VALUES (1, 'Food', 'expense')");
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<int> txCount() async {
    final r = await db
        .customSelect('SELECT COUNT(*) AS c FROM transactions')
        .getSingle();
    return r.read<int>('c');
  }

  Future<String> writeCsv(List<String> dataRows) async {
    final content = StringBuffer('id,date,type,category,account,amount,note\n');
    for (final r in dataRows) {
      content.writeln(r);
    }
    final file = File('${tmp.path}/in.csv');
    await file.writeAsString(content.toString());
    return file.path;
  }

  test('rejects a file whose columns do not match the export', () async {
    final file = File('${tmp.path}/bad.csv');
    await file.writeAsString('foo,bar\n1,2\n');
    final preview = await svc.parse(file.path);
    expect(preview.fatal, ImportFatal.columnMismatch);
  });

  test('detects duplicates against existing rows and skips them', () async {
    final iso = DateTime(2024, 5, 1, 10).toIso8601String();
    final ms = DateTime(2024, 5, 1, 10).millisecondsSinceEpoch;
    await db.customStatement(
        "INSERT INTO transactions (amount, type, category_id, account_id, date_time, note) "
        "VALUES (5500, 'expense', 1, 1, $ms, 'lunch')");

    final path = await writeCsv(['1,$iso,expense,Food,Cash,55.00,lunch']);
    final preview = await svc.parse(path);
    expect(preview.fatal, isNull);
    expect(preview.rows, hasLength(1));
    expect(preview.validCount, 1);
    expect(preview.duplicateCount, 1);

    final result = await svc.commit(preview.rows, skipDuplicates: true);
    expect(result.imported, 0);
    expect(result.skipped, 1);
    expect(await txCount(), 1); // unchanged
  });

  test('imports valid non-duplicate rows and parses decimals losslessly',
      () async {
    final iso = DateTime(2024, 6, 2, 9).toIso8601String();
    final path = await writeCsv([
      '99,$iso,income,,Cash,1000.75,salary',
    ]);
    final preview = await svc.parse(path);
    expect(preview.validCount, 1);
    expect(preview.duplicateCount, 0);
    expect(preview.rows.first.amountMinor, 100075);

    final result = await svc.commit(preview.rows, skipDuplicates: true);
    expect(result.imported, 1);
    expect(await txCount(), 1);
  });

  test('reports row-level errors without importing the bad row', () async {
    final iso = DateTime(2024, 6, 2, 9).toIso8601String();
    final path = await writeCsv([
      '1,$iso,expense,Food,Cash,abc,bad-amount',
      '2,$iso,expense,Food,Unknown Account,12.00,bad-account',
      '3,$iso,expense,Food,Cash,12.00,good',
    ]);
    final preview = await svc.parse(path);
    expect(preview.errorCount, 2);
    expect(preview.validCount, 1);

    final result = await svc.commit(preview.rows, skipDuplicates: false);
    expect(result.imported, 1);
    expect(result.failed, 2);
    expect(await txCount(), 1);
  });
}
