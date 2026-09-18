import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/domain/repository/settings_repository.dart';

/// Seam between the backup payload's `settings` map and wherever settings
/// actually live — fake-able in tests without SharedPreferences.
abstract class SettingsSnapshotStore {
  Future<Map<String, Object?>> dump();
  Future<void> apply(Map<String, Object?> data);
}

/// Adapter over the app's [SettingsRepository].
///
/// Deliberately excluded from backup: `appLockEnabled` — it is device-local
/// security state; a cloud restore must never silently toggle a device lock.
class AppSettingsSnapshotStore implements SettingsSnapshotStore {
  AppSettingsSnapshotStore(this._repo);
  final SettingsRepository _repo;

  @override
  Future<Map<String, Object?>> dump() async {
    final s = _repo.current;
    return {
      'languageTag': s.languageTag,
      'themeMode': s.themeMode.name,
      'currency': s.currency,
      'weekStartDay': s.weekStartDay,
      'budgetStartDay': s.budgetStartDay,
      'digitFormat': s.digitFormat.name,
      'onboarded': s.onboarded,
    };
  }

  @override
  Future<void> apply(Map<String, Object?> data) async {
    // Applied via the public setters so the settings stream fires and the UI
    // (locale, theme, formatters) updates live — no restart needed.
    final lang = data['languageTag'];
    if (lang is String) await _repo.setLanguage(lang);

    final theme = data['themeMode'];
    if (theme is String) {
      await _repo.setThemeMode(ThemeModePref.values
          .firstWhere((e) => e.name == theme, orElse: () => ThemeModePref.system));
    }

    final currency = data['currency'];
    if (currency is String) await _repo.setCurrency(currency);

    final week = data['weekStartDay'];
    if (week is int) await _repo.setWeekStartDay(week);

    final budget = data['budgetStartDay'];
    if (budget is int) await _repo.setBudgetStartDay(budget);

    final digits = data['digitFormat'];
    if (digits is String) {
      await _repo.setDigitFormat(DigitFormat.values
          .firstWhere((e) => e.name == digits, orElse: () => DigitFormat.latin));
    }

    // A restored device has, by definition, been onboarded before.
    if (data['onboarded'] == true) await _repo.markOnboarded();
  }
}
