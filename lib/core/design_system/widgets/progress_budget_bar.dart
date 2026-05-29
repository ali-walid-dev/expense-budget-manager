import 'package:flutter/material.dart';

class ProgressBudgetBar extends StatelessWidget {
  const ProgressBudgetBar({
    super.key,
    required this.spentMinor,
    required this.limitMinor,
    this.overBudget = false,
  });

  final int spentMinor;
  final int limitMinor;
  final bool overBudget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = limitMinor <= 0 ? 0.0 : (spentMinor / limitMinor).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 8,
        backgroundColor: scheme.surfaceContainerHighest,
        color: overBudget ? scheme.error : scheme.primary,
      ),
    );
  }
}
