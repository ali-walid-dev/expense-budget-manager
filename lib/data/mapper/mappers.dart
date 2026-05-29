import 'package:flutter/material.dart';

import 'package:expense_budget_manager/data/local/db/app_database.dart' as d;
import 'package:expense_budget_manager/data/local/db/daos.dart' show TxJoinedRow;
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/recurring_rule.dart';
import 'package:expense_budget_manager/domain/model/transaction.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

Color hexToColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final v = int.parse(cleaned, radix: 16);
  return Color(cleaned.length == 6 ? 0xFF000000 | v : v);
}

String colorToHex(Color c) =>
    '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

IconData iconFromKey(String key) {
  return _iconLookup[key] ?? Icons.category;
}

String iconToKey(IconData icon) {
  return _iconLookup.entries
      .firstWhere((e) => e.value.codePoint == icon.codePoint,
          orElse: () => const MapEntry('category', Icons.category))
      .key;
}

const _iconLookup = <String, IconData>{
  'category': Icons.category,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'shopping_basket': Icons.shopping_basket,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'movie': Icons.movie,
  'local_hospital': Icons.local_hospital,
  'receipt_long': Icons.receipt_long,
  'school': Icons.school,
  'home': Icons.home,
  'attach_money': Icons.attach_money,
  'work': Icons.work,
  'savings': Icons.savings,
  'payments': Icons.payments,
  'account_balance': Icons.account_balance,
  'credit_card': Icons.credit_card,
  'account_balance_wallet': Icons.account_balance_wallet,
  'phone_iphone': Icons.phone_iphone,
  'bolt': Icons.bolt,
};

extension AccountMapper on d.Account {
  Account toDomain() => Account(
        id: id,
        name: name,
        type: type,
        currency: currency,
        initialBalance: initialBalance,
        color: hexToColor(colorHex),
        iconKey: iconKey,
        archived: archived,
      );
}

extension CategoryMapper on d.Category {
  Category toDomain() => Category(
        id: id,
        name: name,
        parentId: parentId,
        type: type,
        color: hexToColor(colorHex),
        icon: iconFromKey(iconKey),
        iconKey: iconKey,
        isDefault: isDefault,
      );
}

extension TransactionMapper on d.Transaction {
  TransactionRecord toDomain() => TransactionRecord(
        id: id,
        amount: amount,
        type: type,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        dateTime: DateTime.fromMillisecondsSinceEpoch(dateTime),
        note: note,
        attachmentPath: attachmentPath,
        recurringId: recurringId,
      );
}

extension TxJoinedRowMapper on TxJoinedRow {
  TransactionWithDetails toDomain() => TransactionWithDetails(
        id: id,
        amountMinor: amount,
        type: type,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        dateTime: DateTime.fromMillisecondsSinceEpoch(dateTime),
        note: note,
        categoryName: categoryName,
        categoryColor:
            categoryColor == null ? null : hexToColor(categoryColor!),
        categoryIcon: categoryIcon == null ? null : iconFromKey(categoryIcon!),
        accountName: accountName,
      );
}

extension BudgetMapper on d.Budget {
  Budget toDomain() => Budget(
        id: id,
        categoryId: categoryId,
        amount: amount,
        period: period,
        startDate: startDate == null ? null : DateTime.fromMillisecondsSinceEpoch(startDate!),
        endDate: endDate == null ? null : DateTime.fromMillisecondsSinceEpoch(endDate!),
        carryOver: carryOver,
      );
}

extension RecurringRuleMapper on d.RecurringRule {
  RecurringRuleModel toDomain() => RecurringRuleModel(
        id: id,
        templateAmount: templateAmount,
        type: type,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        interval: interval,
        nextRunDate: DateTime.fromMillisecondsSinceEpoch(nextRunDate),
        lastRunDate: lastRunDate == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastRunDate!),
        note: note,
      );
}
