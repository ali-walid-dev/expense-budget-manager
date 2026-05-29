import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';

class RecurringRuleModel {
  const RecurringRuleModel({
    required this.id,
    required this.templateAmount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.interval,
    required this.nextRunDate,
    required this.lastRunDate,
    required this.note,
  });

  final int id;
  final int templateAmount;
  final TransactionType type;
  final int? categoryId;
  final int accountId;
  final int? toAccountId;
  final RecurringInterval interval;
  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final String? note;
}
