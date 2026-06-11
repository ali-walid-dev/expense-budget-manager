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
  // `dateTime` clashes with Drift's inherited Table.dateTime() helper, so we
  // name the getter differently while keeping the SQL column as `date_time`.
  IntColumn get occurredAt => integer().named('date_time')();
  TextColumn get note => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
  IntColumn get recurringId =>
      integer().nullable().references(RecurringRules, #id, onDelete: KeyAction.setNull)();
  // Links auto-generated debt payments back to their debt. Nullable; set null
  // when the debt is deleted so historical payments are retained (Feature 4).
  IntColumn get debtId =>
      integer().nullable().references(Debts, #id, onDelete: KeyAction.setNull)();
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
  // Optional user-facing label (Feature 2). Nullable so existing rows migrate
  // cleanly; the UI falls back to the category name when null.
  TextColumn get name => text().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();
  TextColumn get period => text().map(const BudgetPeriodConverter())();
  IntColumn get startDate => integer().nullable()();
  IntColumn get endDate => integer().nullable()();
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();
}

/// A tracked debt that auto-generates a monthly expense transaction per cycle
/// until paid off (Feature 4).
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get creditor => text().nullable()();
  IntColumn get totalAmount => integer()(); // minor units
  IntColumn get monthlyPayment => integer()(); // minor units
  IntColumn get startDate => integer()(); // millis — first payment cycle
  IntColumn get dueDate => integer().nullable()(); // millis
  TextColumn get note => text().nullable()();
  // Account the generated payments are drawn from (required to generate).
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  // 'active' | 'completed' — auto-set to completed when paid >= total.
  TextColumn get status => text().withDefault(const Constant('active'))();
  // Millis of the most recent cycle a payment was generated for; drives
  // idempotent catch-up generation.
  IntColumn get lastGeneratedDate => integer().nullable()();
}

/// A user-defined reminder notification (daily, or on specific weekdays) at a
/// chosen time of day.
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get message => text()();
  IntColumn get hour => integer()(); // 0-23
  IntColumn get minute => integer()(); // 0-59
  // 'daily' | 'weekly'
  TextColumn get frequency => text().withDefault(const Constant('daily'))();
  // Comma-separated DateTime weekday ints (1=Mon..7=Sun) for 'weekly'; empty
  // for 'daily'.
  TextColumn get weekdays => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
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
