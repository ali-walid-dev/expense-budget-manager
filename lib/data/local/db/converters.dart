import 'package:drift/drift.dart';

import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';

class AccountTypeConverter extends TypeConverter<AccountType, String> {
  const AccountTypeConverter();
  @override
  AccountType fromSql(String fromDb) =>
      AccountType.values.firstWhere((e) => e.name == fromDb,
          orElse: () => AccountType.cash);
  @override
  String toSql(AccountType value) => value.name;
}

class CategoryTypeConverter extends TypeConverter<CategoryType, String> {
  const CategoryTypeConverter();
  @override
  CategoryType fromSql(String fromDb) =>
      CategoryType.values.firstWhere((e) => e.name == fromDb,
          orElse: () => CategoryType.expense);
  @override
  String toSql(CategoryType value) => value.name;
}

class TransactionTypeConverter extends TypeConverter<TransactionType, String> {
  const TransactionTypeConverter();
  @override
  TransactionType fromSql(String fromDb) =>
      TransactionType.values.firstWhere((e) => e.name == fromDb,
          orElse: () => TransactionType.expense);
  @override
  String toSql(TransactionType value) => value.name;
}

class BudgetPeriodConverter extends TypeConverter<BudgetPeriod, String> {
  const BudgetPeriodConverter();
  @override
  BudgetPeriod fromSql(String fromDb) =>
      BudgetPeriod.values.firstWhere((e) => e.name == fromDb,
          orElse: () => BudgetPeriod.monthly);
  @override
  String toSql(BudgetPeriod value) => value.name;
}

class RecurringIntervalConverter
    extends TypeConverter<RecurringInterval, String> {
  const RecurringIntervalConverter();
  @override
  RecurringInterval fromSql(String fromDb) =>
      RecurringInterval.values.firstWhere((e) => e.name == fromDb,
          orElse: () => RecurringInterval.monthly);
  @override
  String toSql(RecurringInterval value) => value.name;
}
