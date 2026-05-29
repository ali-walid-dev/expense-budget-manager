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

  Future<void> delete(int id);
}
