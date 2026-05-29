import 'package:expense_budget_manager/domain/model/transaction_type.dart';

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.dateTime,
    required this.note,
    required this.attachmentPath,
    required this.recurringId,
  });

  final int id;
  final int amount; // minor units, positive
  final TransactionType type;
  final int? categoryId;
  final int accountId;
  final int? toAccountId;
  final DateTime dateTime;
  final String? note;
  final String? attachmentPath;
  final int? recurringId;
}
