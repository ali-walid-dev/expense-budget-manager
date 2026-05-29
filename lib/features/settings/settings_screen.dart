import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/core/navigation/app_routes.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          _Section(title: l.language),
          RadioListTile<String>(
            title: Text(l.languageEnglish),
            value: 'en',
            groupValue: settings.languageTag,
            onChanged: (v) => notifier.setLanguage(v!),
          ),
          RadioListTile<String>(
            title: Text(l.languageArabic),
            value: 'ar',
            groupValue: settings.languageTag,
            onChanged: (v) => notifier.setLanguage(v!),
          ),
          _Section(title: l.theme),
          RadioListTile<ThemeModePref>(
            title: Text(l.themeSystem),
            value: ThemeModePref.system,
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.setThemeMode(v!),
          ),
          RadioListTile<ThemeModePref>(
            title: Text(l.themeLight),
            value: ThemeModePref.light,
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.setThemeMode(v!),
          ),
          RadioListTile<ThemeModePref>(
            title: Text(l.themeDark),
            value: ThemeModePref.dark,
            groupValue: settings.themeMode,
            onChanged: (v) => notifier.setThemeMode(v!),
          ),
          _Section(title: l.currency),
          ListTile(
            title: Text(settings.currency),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final code = await showDialog<String>(
                context: context,
                builder: (_) => const _CurrencyPickerDialog(),
              );
              if (code != null) notifier.setCurrency(code);
            },
          ),
          _Section(title: l.digitFormat),
          RadioListTile<DigitFormat>(
            title: Text(l.digitFormatEnglish),
            value: DigitFormat.latin,
            groupValue: settings.digitFormat,
            onChanged: (v) => notifier.setDigitFormat(v!),
          ),
          RadioListTile<DigitFormat>(
            title: Text(l.digitFormatArabic),
            value: DigitFormat.arabic,
            groupValue: settings.digitFormat,
            onChanged: (v) => notifier.setDigitFormat(v!),
          ),
          _Section(title: l.weekStart),
          ListTile(
            title: Text('${settings.weekStartDay}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final day = await _pickDay(context, settings.weekStartDay);
              if (day != null) notifier.setWeekStartDay(day);
            },
          ),
          _Section(title: l.budgetStart),
          ListTile(
            title: Text('${settings.budgetStartDay}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final day = await _pickDayOfMonth(context, settings.budgetStartDay);
              if (day != null) notifier.setBudgetStartDay(day);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l.categories),
            onTap: () => context.push(AppRoutes.categories),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l.accounts),
            onTap: () => context.push(AppRoutes.accounts),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: Text(l.budgets),
            onTap: () => context.push(AppRoutes.budgets),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<int?> _pickDay(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        children: [
          for (var i = 1; i <= 7; i++)
            SimpleDialogOption(
              child: Text('$i'),
              onPressed: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
  }

  Future<int?> _pickDayOfMonth(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        children: [
          for (var i = 1; i <= 28; i++)
            SimpleDialogOption(
              child: Text('$i'),
              onPressed: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                )),
      );
}

class _CurrencyPickerDialog extends StatelessWidget {
  const _CurrencyPickerDialog();
  static const _common = ['EGP', 'USD', 'EUR', 'SAR', 'AED', 'GBP', 'KWD', 'QAR'];
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.currency),
      children: [
        for (final c in _common)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, c),
            child: Text(c),
          ),
      ],
    );
  }
}
