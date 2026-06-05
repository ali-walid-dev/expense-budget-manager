import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/mapper/mappers.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/repository/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this.db);
  final d.AppDatabase db;

  @override
  Stream<List<Category>> watchAll() => db.categoryDao
      .watchAll()
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Stream<List<Category>> watchByType(CategoryType type) =>
      watchAll().map((all) => all.where((c) => c.type == type).toList());

  @override
  Stream<List<CategoryNode>> watchTree() {
    return watchAll().map((all) {
      final roots = all.where((c) => c.parentId == null).toList();
      return roots.map((root) {
        final kids = all.where((c) => c.parentId == root.id).toList();
        return CategoryNode(category: root, children: kids);
      }).toList();
    });
  }

  @override
  Future<int> upsert({
    int? id,
    required String name,
    required CategoryType type,
    required Color color,
    required IconData icon,
    int? parentId,
  }) async {
    final colorHex = colorToHex(color);
    final iconKey = iconToKey(icon);
    if (id == null) {
      return db.categoryDao.insert(d.CategoriesCompanion.insert(
        name: name,
        parentId: Value(parentId),
        type: type,
        colorHex: Value(colorHex),
        iconKey: Value(iconKey),
      ));
    } else {
      final existing = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();
      await db.categoryDao.update_(existing.copyWith(
        name: name,
        parentId: Value(parentId),
        type: type,
        colorHex: colorHex,
        iconKey: iconKey,
      ));
      return id;
    }
  }

  @override
  Future<({int childCount, int transactionCount})> deleteImpact(int id) async {
    final childRows =
        await (db.select(db.categories)..where((c) => c.parentId.equals(id)))
            .get();
    final txRow = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {db.transactions},
    ).getSingle();
    return (
      childCount: childRows.length,
      transactionCount: txRow.read<int>('c'),
    );
  }

  @override
  Future<void> delete(int id, {bool reassignChildrenToTopLevel = false}) async {
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.isDefault) return;

    final impact = await deleteImpact(id);
    if (impact.childCount > 0) {
      if (!reassignChildrenToTopLevel) {
        throw StateError(
            'Category $id has ${impact.childCount} subcategories; '
            'pass reassignChildrenToTopLevel to detach them.');
      }
      // Detach children to top level (parent_id = null) so they and their
      // transactions survive.
      await (db.update(db.categories)..where((c) => c.parentId.equals(id)))
          .write(const d.CategoriesCompanion(parentId: Value(null)));
    }
    // Transactions on this category have category_id set null by the FK.
    await db.categoryDao.deleteById(id);
  }
}
