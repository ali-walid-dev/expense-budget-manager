import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// Every user-data table, by SQL name. Order is irrelevant for restore (FK
/// checks are deferred to commit) but kept logical for readability.
///
/// SECURITY: these constants are the only identifiers ever interpolated into
/// SQL. Table/column names arriving in a backup file are validated against
/// this whitelist + PRAGMA table_info, never trusted.
const kBackupTables = <String>[
  'accounts',
  'categories',
  'transactions',
  'tags',
  'transaction_tags',
  'budgets',
  'debts',
  'recurring_rules',
  'reminders',
];

typedef DbSnapshot = Map<String, List<Map<String, Object?>>>;

/// Dumps every table as raw column->value maps (SQLite primitives only, so
/// the result is JSON-safe and round-trips byte-for-byte). Runs inside one
/// transaction for a consistent point-in-time snapshot.
Future<DbSnapshot> dumpDatabase(AppDatabase db) {
  return db.transaction(() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final table in kBackupTables) {
      final rows = await db.customSelect('SELECT * FROM "$table"').get();
      out[table] = rows.map((r) => Map<String, Object?>.from(r.data)).toList();
    }
    return out;
  });
}

/// Replaces the entire database content with [snapshot], atomically: a single
/// transaction with deferred FK enforcement. Any failure (bad table, unknown
/// column, constraint violation) rolls back and leaves existing data intact —
/// the "temp store then swap" requirement is satisfied by SQLite transactional
/// semantics, which are strictly stronger.
///
/// Rows from older app versions may lack newly added columns: inserts use
/// explicit column lists, so missing columns fall back to SQL defaults / NULL
/// (all post-v1 columns were added nullable or with defaults). Unknown columns
/// mean the backup is newer or damaged -> [CorruptBackupFailure].
Future<void> restoreDatabase(AppDatabase db, DbSnapshot snapshot) async {
  for (final table in snapshot.keys) {
    if (!kBackupTables.contains(table)) {
      throw CorruptBackupFailure('unknown table "$table"');
    }
  }

  await db.transaction(() async {
    // Transaction-scoped: FKs are validated at COMMIT, so delete/insert order
    // does not matter (categories self-reference, transactions reference
    // everything).
    await db.customStatement('PRAGMA defer_foreign_keys = ON');

    for (final table in kBackupTables) {
      await db.customStatement('DELETE FROM "$table"');
    }

    for (final table in kBackupTables) {
      final rows = snapshot[table];
      if (rows == null || rows.isEmpty) continue;

      final allowed = await _columnsOf(db, table);
      for (final row in rows) {
        if (row.isEmpty) continue;
        final cols = row.keys.toList();
        for (final c in cols) {
          if (!allowed.contains(c)) {
            throw CorruptBackupFailure('unknown column "$table.$c"');
          }
        }
        final colSql = cols.map((c) => '"$c"').join(', ');
        final placeholders = List.filled(cols.length, '?').join(', ');
        await db.customInsert(
          'INSERT INTO "$table" ($colSql) VALUES ($placeholders)',
          variables: [for (final c in cols) Variable(row[c])],
        );
      }
    }
  });

  // customStatement/customInsert don't feed drift's stream watcher — tell
  // every open stream query to re-run so the UI refreshes without a restart.
  db.markTablesUpdated(db.allTables);
}

Future<Set<String>> _columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info("$table")').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}
