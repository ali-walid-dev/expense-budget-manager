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
  Future<void> delete(int id) async {
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null || row.isDefault) return;
    await db.categoryDao.deleteById(id);
  }
}
