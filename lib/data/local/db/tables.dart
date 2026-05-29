import 'package:drift/drift.dart';

import 'package:expense_budget_manager/data/local/db/converters.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type =>
      text().map(const AccountTypeConverter())();
  TextColumn get currency => text().withDefault(const Constant('EGP'))();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get colorHex => text().withDefault(const Constant('#16B981'))();
  TextColumn get iconKey => text().withDefault(const Constant('payments'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.cascade)();
  TextColumn get type =>
      text().map(const CategoryTypeConverter())();
  TextColumn get colorHex => text().withDefault(const Constant('#16B981'))();
  TextColumn get iconKey => text().withDefault(const Constant('category'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()(); // minor units, always positive
  TextColumn get type => text().map(const TransactionTypeConverter())();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get toAccountId =>
      integer().nullable().references(Accounts, #id, onDelete: KeyAction.setNull)();
  IntColumn get dateTime => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
  IntColumn get recurringId =>
      integer().nullable().references(RecurringRules, #id, onDelete: KeyAction.setNull)();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class TransactionTags extends Table {
  IntColumn get transactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();
  TextColumn get period => text().map(const BudgetPeriodConverter())();
  IntColumn get startDate => integer().nullable()();
  IntColumn get endDate => integer().nullable()();
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();
}

class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateAmount => integer()();
  TextColumn get type => text().map(const TransactionTypeConverter())();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer()();
  IntColumn get toAccountId => integer().nullable()();
  TextColumn get interval => text().map(const RecurringIntervalConverter())();
  IntColumn get nextRunDate => integer()();
  IntColumn get lastRunDate => integer().nullable()();
  TextColumn get note => text().nullable()();
}
