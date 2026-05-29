import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.parentId,
    required this.type,
    required this.color,
    required this.icon,
    required this.iconKey,
    required this.isDefault,
  });

  final int id;
  final String name;
  final int? parentId;
  final CategoryType type;
  final Color color;
  final IconData icon;
  final String iconKey;
  final bool isDefault;
}

class CategoryNode {
  const CategoryNode({required this.category, required this.children});
  final Category category;
  final List<Category> children;
}
