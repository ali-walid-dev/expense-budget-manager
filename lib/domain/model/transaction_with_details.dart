import 'package:flutter/material.dart';

import 'package:expense_budget_manager/domain/model/transaction_type.dart';

class TransactionWithDetails {
  const TransactionWithDetails({
    required this.id,
    required this.amountMinor,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.dateTime,
    required this.note,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.accountName,
  });

  final int id;
  final int amountMinor;
  final TransactionType type;
  final int? categoryId;
  final int accountId;
  final int? toAccountId;
  final DateTime dateTime;
  final String? note;
  final String? categoryName;
  final Color? categoryColor;
  final IconData? categoryIcon;
  final String accountName;
}
