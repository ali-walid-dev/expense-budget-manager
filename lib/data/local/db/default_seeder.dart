import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/category.dart';

class DefaultSeeder {
  DefaultSeeder(this.db);
  final AppDatabase db;

  /// Idempotent: only seeds if the categories table is empty.
  Future<void> seedIfEmpty() async {
    final existing = await db.select(db.categories).get();
    if (existing.isNotEmpty) return;

    await db.transaction(() async {
      // Expense parents
      final food = await db.into(db.categories).insert(CategoriesCompanion.insert(
            name: 'Food',
            type: CategoryType.expense,
            colorHex: const Value('#D85A30'),
            iconKey: const Value('restaurant'),
            isDefault: const Value(true),
          ));
      await _addSub(food, 'Restaurants', '#D85A30', 'restaurant');
      await _addSub(food, 'Coffee', '#A0522D', 'local_cafe');
      await _addSub(food, 'Groceries', '#16B981', 'shopping_basket');

      await _addRoot('Transportation', '#185FA5', 'directions_car');
      await _addRoot('Shopping', '#EC4899', 'shopping_bag');
      await _addRoot('Entertainment', '#8B5CF6', 'movie');
      await _addRoot('Health', '#14B8A6', 'local_hospital');
      await _addRoot('Bills', '#BA7517', 'receipt_long');
      await _addRoot('Education', '#185FA5', 'school');
      await _addRoot('Home', '#0F6E56', 'home');

      // Income
      await _addRoot('Salary', '#16B981', 'attach_money', type: CategoryType.income);
      await _addRoot('Freelance', '#16B981', 'work', type: CategoryType.income);
      await _addRoot('Investments', '#185FA5', 'savings', type: CategoryType.income);

      // Default accounts
      final cashExists = await (db.select(db.accounts)).get();
      if (cashExists.isEmpty) {
        await db.into(db.accounts).insert(AccountsCompanion.insert(
              name: 'Cash',
              type: AccountType.cash,
              colorHex: const Value('#16B981'),
              iconKey: const Value('payments'),
            ));
        await db.into(db.accounts).insert(AccountsCompanion.insert(
              name: 'Bank',
              type: AccountType.bank,
              colorHex: const Value('#185FA5'),
              iconKey: const Value('account_balance'),
            ));
      }
    });
  }

  Future<int> _addRoot(String name, String color, String icon,
      {CategoryType type = CategoryType.expense}) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          name: name,
          type: type,
          colorHex: Value(color),
          iconKey: Value(icon),
          isDefault: const Value(true),
        ));
  }

  Future<int> _addSub(int parent, String name, String color, String icon) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          name: name,
          parentId: Value(parent),
          type: CategoryType.expense,
          colorHex: Value(color),
          iconKey: Value(icon),
          isDefault: const Value(true),
        ));
  }
}
