import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_budget_manager/features/analytics/analytics_math.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

/// 1 Food (parent)
///   11 Restaurants
///   12 Groceries
/// 2 Transport (parent)
///   21 Taxi
final categories = <Category>[
  _cat(1, 'Food', null, Colors.orange),
  _cat(11, 'Restaurants', 1, Colors.orange),
  _cat(12, 'Groceries', 1, Colors.orange),
  _cat(2, 'Transport', null, Colors.blue),
  _cat(21, 'Taxi', 2, Colors.blue),
];

Category _cat(int id, String name, int? parentId, Color color) => Category(
      id: id,
      name: name,
      parentId: parentId,
      type: CategoryType.expense,
      color: color,
      icon: Icons.category,
      iconKey: 'category',
      isDefault: false,
    );

TransactionWithDetails _tx({
  required int id,
  required int amountMinor,
  int? categoryId,
  int accountId = 1,
  DateTime? at,
  TransactionType type = TransactionType.expense,
}) =>
    TransactionWithDetails(
      id: id,
      amountMinor: amountMinor,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: null,
      dateTime: at ?? DateTime(2026, 3, 10),
      note: null,
      categoryName: null,
      categoryColor: null,
      categoryIcon: null,
      accountName: 'Cash',
    );

String _direct(String parent) => '$parent (direct)';

void main() {
  group('buildCategoryBreakdown', () {
    final txs = [
      _tx(id: 1, amountMinor: 1000, categoryId: 11), // Food > Restaurants
      _tx(id: 2, amountMinor: 500, categoryId: 12), // Food > Groceries
      _tx(id: 3, amountMinor: 2000, categoryId: 21), // Transport > Taxi
    ];

    test('parent grouping rolls subcategories up into their parent', () {
      final slices = buildCategoryBreakdown(
        transactions: txs,
        categories: categories,
        grouping: CategoryGrouping.parent,
        directOnParentLabel: _direct,
      );

      expect(slices.map((s) => s.name), ['Transport', 'Food']);
      expect(slices.first.totalMinor, 2000);
      expect(slices.last.totalMinor, 1500);
    });

    test('subcategory grouping gives every subcategory its own slice', () {
      final slices = buildCategoryBreakdown(
        transactions: txs,
        categories: categories,
        grouping: CategoryGrouping.sub,
        directOnParentLabel: _direct,
      );

      expect(slices.map((s) => s.name), ['Taxi', 'Restaurants', 'Groceries']);
      expect(slices.map((s) => s.totalMinor), [2000, 1000, 500]);
    });

    test('subcategory slices of one parent are visually distinguishable', () {
      final slices = buildCategoryBreakdown(
        transactions: txs,
        categories: categories,
        grouping: CategoryGrouping.sub,
        directOnParentLabel: _direct,
      );

      final restaurants = slices.firstWhere((s) => s.name == 'Restaurants');
      final groceries = slices.firstWhere((s) => s.name == 'Groceries');
      expect(restaurants.color, isNot(groceries.color));
    });

    test('spending booked on a parent itself is labelled as direct', () {
      final slices = buildCategoryBreakdown(
        transactions: [_tx(id: 4, amountMinor: 300, categoryId: 1)],
        categories: categories,
        grouping: CategoryGrouping.sub,
        directOnParentLabel: _direct,
      );

      expect(slices.single.name, 'Food (direct)');
      expect(slices.single.totalMinor, 300);
    });

    test('income and transfers are excluded from the expense breakdown', () {
      final slices = buildCategoryBreakdown(
        transactions: [
          _tx(id: 5, amountMinor: 9999, categoryId: 11, type: TransactionType.income),
          _tx(id: 6, amountMinor: 100, categoryId: 11),
        ],
        categories: categories,
        grouping: CategoryGrouping.sub,
        directOnParentLabel: _direct,
      );

      expect(slices.single.totalMinor, 100);
    });

    test('uncategorised spending is dropped rather than crashing', () {
      final slices = buildCategoryBreakdown(
        transactions: [_tx(id: 7, amountMinor: 100, categoryId: null)],
        categories: categories,
        grouping: CategoryGrouping.parent,
        directOnParentLabel: _direct,
      );

      expect(slices, isEmpty);
    });
  });

  group('categoryMatchesFilter', () {
    final index = parentIndex(categories);

    test('no filter matches everything', () {
      expect(categoryMatchesFilter(txCategoryId: 11, filterId: null, parentOf: index), isTrue);
      expect(categoryMatchesFilter(txCategoryId: null, filterId: null, parentOf: index), isTrue);
    });

    test('a parent filter matches its subcategories', () {
      expect(categoryMatchesFilter(txCategoryId: 11, filterId: 1, parentOf: index), isTrue);
      expect(categoryMatchesFilter(txCategoryId: 1, filterId: 1, parentOf: index), isTrue);
      expect(categoryMatchesFilter(txCategoryId: 21, filterId: 1, parentOf: index), isFalse);
    });

    test('a subcategory filter matches only that subcategory', () {
      expect(categoryMatchesFilter(txCategoryId: 11, filterId: 11, parentOf: index), isTrue);
      expect(categoryMatchesFilter(txCategoryId: 12, filterId: 11, parentOf: index), isFalse);
      expect(categoryMatchesFilter(txCategoryId: 1, filterId: 11, parentOf: index), isFalse);
    });

    test('an uncategorised transaction matches no explicit filter', () {
      expect(categoryMatchesFilter(txCategoryId: null, filterId: 1, parentOf: index), isFalse);
    });
  });

  group('specificMonthRange', () {
    test('covers the calendar month when the budget starts on the 1st', () {
      final r = specificMonthRange(year: 2026, month: 3, monthStartDay: 1);

      expect(r.start, DateTime(2026, 3, 1));
      expect(r.end, DateTime(2026, 4, 1));
      expect(r.contains(DateTime(2026, 3, 31, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 4, 1)), isFalse);
    });

    test('shifts with a custom budget start day', () {
      final r = specificMonthRange(year: 2026, month: 3, monthStartDay: 10);

      expect(r.start, DateTime(2026, 3, 10));
      expect(r.end, DateTime(2026, 4, 10));
      expect(r.contains(DateTime(2026, 3, 9)), isFalse);
    });

    test('rolls over the year boundary in December', () {
      final r = specificMonthRange(year: 2026, month: 12, monthStartDay: 1);

      expect(r.end, DateTime(2027, 1, 1));
    });
  });
}
