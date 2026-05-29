import 'package:expense_budget_manager/core/common/money_formatter.dart';

enum ThemeModePref { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.languageTag,
    required this.themeMode,
    required this.currency,
    required this.weekStartDay,
    required this.budgetStartDay,
    required this.digitFormat,
    required this.onboarded,
    required this.appLockEnabled,
  });

  final String languageTag;
  final ThemeModePref themeMode;
  final String currency;
  final int weekStartDay;
  final int budgetStartDay;
  final DigitFormat digitFormat;
  final bool onboarded;
  final bool appLockEnabled;

  AppSettings copyWith({
    String? languageTag,
    ThemeModePref? themeMode,
    String? currency,
    int? weekStartDay,
    int? budgetStartDay,
    DigitFormat? digitFormat,
    bool? onboarded,
    bool? appLockEnabled,
  }) =>
      AppSettings(
        languageTag: languageTag ?? this.languageTag,
        themeMode: themeMode ?? this.themeMode,
        currency: currency ?? this.currency,
        weekStartDay: weekStartDay ?? this.weekStartDay,
        budgetStartDay: budgetStartDay ?? this.budgetStartDay,
        digitFormat: digitFormat ?? this.digitFormat,
        onboarded: onboarded ?? this.onboarded,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      );

  static const initial = AppSettings(
    languageTag: 'en',
    themeMode: ThemeModePref.system,
    currency: 'EGP',
    weekStartDay: DateTime.saturday,
    budgetStartDay: 1,
    digitFormat: DigitFormat.latin,
    onboarded: false,
    appLockEnabled: false,
  );
}
