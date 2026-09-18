import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/core/design_system/app_theme.dart';
import 'package:expense_budget_manager/core/design_system/widgets/money_text.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';

class TransactionRow extends ConsumerWidget {
  const TransactionRow({super.key, required this.detail});
  final TransactionWithDetails detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateF = ref.watch(dateFormatterProvider);
    final color = switch (detail.type) {
      TransactionType.expense => AppTheme.expenseColor(context),
      TransactionType.income => AppTheme.incomeColor(context),
      TransactionType.transfer => Theme.of(context).colorScheme.primary,
    };
    final signedAmount = switch (detail.type) {
      TransactionType.expense => -detail.amountMinor,
      TransactionType.income => detail.amountMinor,
      TransactionType.transfer => detail.amountMinor,
    };
    // Category is the title. When the row has no category (e.g. transfers) the
    // note stands in as the title so it isn't lost — and is then not repeated
    // as a subtitle below.
    final note = detail.note?.trim() ?? '';
    final hasNote = note.isNotEmpty;
    final title = detail.categoryName ?? (hasNote ? note : '—');
    final showNoteSubtitle = hasNote && detail.categoryName != null;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: (detail.categoryColor ?? color).withOpacity(0.15),
            child: Icon(
              detail.categoryIcon ?? Icons.swap_horiz,
              color: detail.categoryColor ?? color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showNoteSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${detail.accountName} • ${dateF.dayMonth(detail.dateTime)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          MoneyText(
            minorUnits: signedAmount,
            signed: detail.type != TransactionType.transfer,
            color: color,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
