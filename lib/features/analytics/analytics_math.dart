import 'package:flutter/material.dart';

import 'package:expense_budget_manager/core/common/time_range.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

/// Whether the charts show one slice per top-level category or one per
/// subcategory.
enum CategoryGrouping { parent, sub }

/// One slice / bar of the category chart.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.name,
    required this.totalMinor,
    required this.color,
    this.isDirectOnParent = false,
  });

  final int categoryId;
  final String name;
  final int totalMinor;
  final Color color;

  /// True when this slice is spending booked straight onto a parent category
  /// while subcategories are being shown. The screen labels it, so this file
  /// stays free of localisation.
  final bool isDirectOnParent;
}

/// Maps every category id to its top-level parent (a parent maps to itself).
///
/// Only one level of nesting exists in the UI, but this walks the chain so a
/// deeper tree arriving from an import cannot produce an orphan slice.
Map<int, int> parentIndex(List<Category> categories) {
  final byId = {for (final c in categories) c.id: c};
  final out = <int, int>{};
  for (final c in categories) {
    var current = c;
    final seen = <int>{c.id};
    while (current.parentId != null && byId.containsKey(current.parentId)) {
      if (!seen.add(current.parentId!)) break; // damaged cycle
      current = byId[current.parentId]!;
    }
    out[c.id] = current.id;
  }
  return out;
}

/// Whether a transaction passes the report's category filter.
///
/// Selecting a parent includes everything beneath it; selecting a
/// subcategory narrows to exactly that one.
bool categoryMatchesFilter({
  required int? txCategoryId,
  required int? filterId,
  required Map<int, int> parentOf,
}) {
  if (filterId == null) return true;
  if (txCategoryId == null) return false;
  if (txCategoryId == filterId) return true;
  return parentOf[txCategoryId] == filterId;
}

/// The range covering one specific calendar month, honouring the user's
/// budget start day (a start day of 10 means "10 March to 10 April").
TimeRange specificMonthRange({
  required int year,
  required int month,
  int monthStartDay = 1,
}) =>
    TimeRange(
      DateTime(year, month, monthStartDay),
      DateTime(year, month + 1, monthStartDay),
    );

/// Expense totals per category, largest first.
///
/// [directOnParentLabel] names spending booked straight onto a parent category
/// when subcategories are shown, so it is never confused with the parent's
/// rolled-up total. It is passed in rather than built here to keep this file
/// free of localisation.
List<CategorySlice> buildCategoryBreakdown({
  required Iterable<TransactionWithDetails> transactions,
  required List<Category> categories,
  required CategoryGrouping grouping,
  required String Function(String parentName) directOnParentLabel,
}) {
  final byId = {for (final c in categories) c.id: c};
  final parentOf = parentIndex(categories);

  final totals = <int, int>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense) continue;
    final categoryId = t.categoryId;
    // Uncategorised spending has no slice to belong to.
    if (categoryId == null || !byId.containsKey(categoryId)) continue;

    final key = grouping == CategoryGrouping.parent
        ? (parentOf[categoryId] ?? categoryId)
        : categoryId;
    totals[key] = (totals[key] ?? 0) + t.amountMinor;
  }

  // Sub-slices of one parent share its hue, so the chart still reads as
  // groups; the lightness shift keeps them apart from each other.
  final shadeIndex = <int, int>{};
  if (grouping == CategoryGrouping.sub) {
    final siblings = <int, List<int>>{};
    for (final id in totals.keys) {
      siblings.putIfAbsent(parentOf[id] ?? id, () => []).add(id);
    }
    for (final group in siblings.values) {
      group.sort();
      for (var i = 0; i < group.length; i++) {
        shadeIndex[group[i]] = i;
      }
    }
  }

  final slices = totals.entries.map((e) {
    final category = byId[e.key]!;
    final isParent = category.parentId == null;
    final showDirect = grouping == CategoryGrouping.sub && isParent;
    return CategorySlice(
      categoryId: e.key,
      name: showDirect ? directOnParentLabel(category.name) : category.name,
      isDirectOnParent: showDirect,
      totalMinor: e.value,
      color: grouping == CategoryGrouping.sub
          ? _shade(byId[parentOf[e.key]] ?? category, shadeIndex[e.key] ?? 0)
          : category.color,
    );
  }).toList()
    ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));

  return slices;
}

/// Nth shade of a parent's colour: same hue, stepped lightness, clamped so it
/// never washes out to white or collapses to black.
Color _shade(Category parent, int index) {
  if (index == 0) return parent.color;
  final hsl = HSLColor.fromColor(parent.color);
  final lightness = (hsl.lightness + index * 0.12).clamp(0.25, 0.80);
  return hsl.withLightness(lightness).toColor();
}
