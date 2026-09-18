import 'package:flutter/material.dart';

import 'package:expense_budget_manager/domain/model/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchAll();
  Stream<List<Category>> watchByType(CategoryType type);
  Stream<List<CategoryNode>> watchTree();

  Future<int> upsert({
    int? id,
    required String name,
    required CategoryType type,
    required Color color,
    required IconData icon,
    int? parentId,
  });

  /// What deleting [id] would affect: how many direct subcategories would be
  /// reassigned to top level, and how many transactions would become
  /// uncategorized. Lets the UI show an informed confirmation (Feature 1).
  Future<({int childCount, int transactionCount})> deleteImpact(int id);

  /// Deletes a category. If it has subcategories, [reassignChildrenToTopLevel]
  /// must be true — they are detached to top level rather than deleted, so no
  /// transaction is ever orphaned. Transactions on the deleted category itself
  /// become uncategorized (FK onDelete: setNull). Default categories are never
  /// deleted.
  Future<void> delete(int id, {bool reassignChildrenToTopLevel = false});
}
