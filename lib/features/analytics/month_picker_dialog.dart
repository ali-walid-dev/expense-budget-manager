import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

/// Picks one calendar month. Flutter ships a day picker and a range picker but
/// no month picker, and "report on March" is a month, not a range the user
/// should have to spell out as two dates.
///
/// Returns the first day of the chosen month, or null if dismissed.
Future<DateTime?> showMonthPickerDialog(
  BuildContext context, {
  required DateTime initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});
  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthName = DateFormat.MMM(locale);
    final now = DateTime.now();

    return AlertDialog(
      title: Text(l.selectMonth),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _year--),
                ),
                Text('$_year',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  // A report about the future is never useful.
                  onPressed:
                      _year >= now.year ? null : () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var m = 1; m <= 12; m++)
                  _MonthCell(
                    label: monthName.format(DateTime(_year, m)),
                    selected: _year == widget.initial.year &&
                        m == widget.initial.month,
                    // Months that have not happened yet hold no data.
                    enabled: _year < now.year || m <= now.month,
                    onTap: () => Navigator.pop(context, DateTime(_year, m)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: enabled
                  ? (selected ? scheme.onPrimaryContainer : null)
                  : scheme.onSurface.withOpacity(0.38),
            ),
          ),
        ),
      ),
    );
  }
}
