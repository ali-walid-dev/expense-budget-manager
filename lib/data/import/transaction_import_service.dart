import 'dart:io';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

import 'package:expense_budget_manager/core/common/amount_codec.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/domain/model/transaction_type.dart';

/// Why a file can't be imported at all (vs. per-row issues).
enum ImportFatal { unsupported, unreadable, empty, columnMismatch }

/// The canonical export/import columns, in order (must match the CSV export).
const kImportColumns = ['id', 'date', 'type', 'category', 'account', 'amount', 'note'];

class ImportRow {
  ImportRow({
    required this.rowNumber,
    required this.categoryName,
    required this.accountName,
    this.error,
    this.duplicate = false,
    this.amountMinor,
    this.type,
    this.accountId,
    this.categoryId,
    this.dateTime,
    this.note,
  });

  final int rowNumber; // 1-based, as seen in the file (excludes header)
  final String categoryName;
  final String accountName;
  final String? error; // null => valid
  final bool duplicate;

  final int? amountMinor;
  final TransactionType? type;
  final int? accountId;
  final int? categoryId;
  final DateTime? dateTime;
  final String? note;

  bool get valid => error == null;
}

class ImportPreview {
  ImportPreview({this.fatal, this.rows = const []});
  final ImportFatal? fatal;
  final List<ImportRow> rows;

  int get validCount => rows.where((r) => r.valid).length;
  int get duplicateCount => rows.where((r) => r.valid && r.duplicate).length;
  int get errorCount => rows.where((r) => !r.valid).length;
}

class ImportResult {
  const ImportResult({required this.imported, required this.skipped, required this.failed});
  final int imported;
  final int skipped;
  final int failed;
}

/// Parses CSV/XLSX exports and imports them back, mirroring the export format
/// (Feature 7). Decimal parsing reuses [AmountCodec] so round-trips are
/// lossless; commits run in a single DB transaction so a bad file can never
/// partially corrupt the database.
class TransactionImportService {
  TransactionImportService(this.db);
  final d.AppDatabase db;

  Future<ImportPreview> parse(String path) async {
    final ext = p.extension(path).toLowerCase();
    List<List<dynamic>> table;
    try {
      if (ext == '.csv') {
        final content = await File(path).readAsString();
        table = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
            .convert(content.replaceAll('\r\n', '\n'));
      } else if (ext == '.xlsx') {
        final bytes = await File(path).readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables.values.isEmpty ? null : excel.tables.values.first;
        if (sheet == null) return ImportPreview(fatal: ImportFatal.empty);
        table = sheet.rows
            .map((row) => row.map((c) => c?.value?.toString() ?? '').toList())
            .toList();
      } else {
        return ImportPreview(fatal: ImportFatal.unsupported);
      }
    } catch (_) {
      return ImportPreview(fatal: ImportFatal.unreadable);
    }

    if (table.isEmpty) return ImportPreview(fatal: ImportFatal.empty);
    final header =
        table.first.map((e) => e.toString().trim().toLowerCase()).toList();
    if (!_headerMatches(header)) {
      return ImportPreview(fatal: ImportFatal.columnMismatch);
    }

    // Lookups for resolving names -> ids.
    final cats = await db.select(db.categories).get();
    final accts = await db.select(db.accounts).get();
    final catByName = <String, int>{
      for (final c in cats) c.name.trim().toLowerCase(): c.id,
    };
    final catNameById = <int, String>{for (final c in cats) c.id: c.name};
    final acctByName = <String, int>{
      for (final a in accts) a.name.trim().toLowerCase(): a.id,
    };

    // Existing transactions -> duplicate keys.
    final existing = await db.select(db.transactions).get();
    final existingKeys = <String>{
      for (final t in existing)
        _dupKey(
          DateTime.fromMillisecondsSinceEpoch(t.occurredAt),
          t.amount,
          t.categoryId == null ? '' : (catNameById[t.categoryId] ?? ''),
          t.note ?? '',
        ),
    };

    final rows = <ImportRow>[];
    for (var i = 1; i < table.length; i++) {
      final cells = table[i];
      // Skip blank trailing lines.
      if (cells.every((c) => c.toString().trim().isEmpty)) continue;
      rows.add(_parseRow(i, cells, catByName, acctByName, existingKeys));
    }
    return ImportPreview(rows: rows);
  }

  ImportRow _parseRow(
    int index,
    List<dynamic> cells,
    Map<String, int> catByName,
    Map<String, int> acctByName,
    Set<String> existingKeys,
  ) {
    String cell(int i) => i < cells.length ? cells[i].toString().trim() : '';
    final dateStr = cell(1);
    final typeStr = cell(2).toLowerCase();
    final categoryName = cell(3);
    final accountName = cell(4);
    final amountStr = cell(5);
    final note = cell(6);

    final errors = <String>[];

    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {
      errors.add('invalid date "$dateStr"');
    }

    final type = TransactionType.values
        .where((t) => t.name == typeStr)
        .cast<TransactionType?>()
        .firstOrNull;
    if (type == null) errors.add('invalid type "$typeStr"');

    final amountMinor = AmountCodec.decode(amountStr);
    if (amountMinor == null || amountMinor <= 0) {
      errors.add('invalid amount "$amountStr"');
    }

    final accountId = acctByName[accountName.toLowerCase()];
    if (accountName.isEmpty) {
      errors.add('missing account');
    } else if (accountId == null) {
      errors.add('unknown account "$accountName"');
    }

    // Category is optional; unknown names import as uncategorized.
    final categoryId =
        categoryName.isEmpty ? null : catByName[categoryName.toLowerCase()];

    if (errors.isNotEmpty) {
      return ImportRow(
        rowNumber: index,
        categoryName: categoryName,
        accountName: accountName,
        error: errors.join('; '),
      );
    }

    final dup = existingKeys.contains(
        _dupKey(date!, amountMinor!, categoryName, note));

    return ImportRow(
      rowNumber: index,
      categoryName: categoryName,
      accountName: accountName,
      duplicate: dup,
      amountMinor: amountMinor,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      dateTime: date,
      note: note.isEmpty ? null : note,
    );
  }

  Future<ImportResult> commit(
    List<ImportRow> rows, {
    required bool skipDuplicates,
  }) async {
    var imported = 0, skipped = 0, failed = 0;
    await db.transaction(() async {
      for (final r in rows) {
        if (!r.valid) {
          failed++;
          continue;
        }
        if (skipDuplicates && r.duplicate) {
          skipped++;
          continue;
        }
        await db.transactionDao.insert(d.TransactionsCompanion.insert(
          amount: r.amountMinor!,
          type: r.type!,
          accountId: r.accountId!,
          categoryId: Value(r.categoryId),
          occurredAt: r.dateTime!.millisecondsSinceEpoch,
          note: Value(r.note),
        ));
        imported++;
      }
    });
    return ImportResult(imported: imported, skipped: skipped, failed: failed);
  }

  bool _headerMatches(List<String> header) {
    if (header.length < kImportColumns.length) return false;
    for (var i = 0; i < kImportColumns.length; i++) {
      if (header[i] != kImportColumns[i]) return false;
    }
    return true;
  }

  /// Duplicate identity: date + amount(minor) + category name + note.
  static String _dupKey(DateTime date, int amountMinor, String category, String note) =>
      '${date.toIso8601String()}|$amountMinor|${category.trim().toLowerCase()}|${note.trim()}';
}
