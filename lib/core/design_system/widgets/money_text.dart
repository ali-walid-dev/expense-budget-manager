import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';

class MoneyText extends ConsumerWidget {
  const MoneyText({
    super.key,
    required this.minorUnits,
    this.style,
    this.signed = false,
    this.color,
  });

  final int minorUnits;
  final TextStyle? style;
  final bool signed;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(moneyFormatterProvider);
    final text = m.format(minorUnits, signed: signed);
    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(color: color),
      textDirection: TextDirection.ltr, // money is always LTR
    );
  }
}
