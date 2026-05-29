import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/domain/repository/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);
  final SharedPreferences _prefs;

  final _controller = StreamController<AppSettings>.broadcast();
  AppSettings _current = AppSettings.initial;

  static const _kLang = 'lang';
  static const _kTheme = 'theme';
  static const _kCurrency = 'currency';
  static const _kWeekStart = 'week_start';
  static const _kBudgetStart = 'budget_start';
  static const _kDigit = 'digit_fmt';
  static const _kOnboarded = 'onboarded';
  static const _kAppLock = 'app_lock';

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> load() async {
    _current = AppSettings(
      languageTag: _prefs.getString(_kLang) ?? 'en',
      themeMode: ThemeModePref.values.firstWhere(
        (e) => e.name == _prefs.getString(_kTheme),
        orElse: () => ThemeModePref.system,
      ),
      currency: _prefs.getString(_kCurrency) ?? 'EGP',
      weekStartDay: _prefs.getInt(_kWeekStart) ?? DateTime.saturday,
      budgetStartDay: _prefs.getInt(_kBudgetStart) ?? 1,
      digitFormat: DigitFormat.values.firstWhere(
        (e) => e.name == _prefs.getString(_kDigit),
        orElse: () => DigitFormat.latin,
      ),
      onboarded: _prefs.getBool(_kOnboarded) ?? false,
      appLockEnabled: _prefs.getBool(_kAppLock) ?? false,
    );
    _controller.add(_current);
  }

  void _emit(AppSettings next) {
    _current = next;
    _controller.add(next);
  }

  @override
  Future<void> setLanguage(String tag) async {
    await _prefs.setString(_kLang, tag);
    _emit(_current.copyWith(languageTag: tag));
  }

  @override
  Future<void> setThemeMode(ThemeModePref mode) async {
    await _prefs.setString(_kTheme, mode.name);
    _emit(_current.copyWith(themeMode: mode));
  }

  @override
  Future<void> setCurrency(String code) async {
    await _prefs.setString(_kCurrency, code);
    _emit(_current.copyWith(currency: code));
  }

  @override
  Future<void> setWeekStartDay(int day) async {
    await _prefs.setInt(_kWeekStart, day);
    _emit(_current.copyWith(weekStartDay: day));
  }

  @override
  Future<void> setBudgetStartDay(int day) async {
    await _prefs.setInt(_kBudgetStart, day);
    _emit(_current.copyWith(budgetStartDay: day));
  }

  @override
  Future<void> setDigitFormat(DigitFormat fmt) async {
    await _prefs.setString(_kDigit, fmt.name);
    _emit(_current.copyWith(digitFormat: fmt));
  }

  @override
  Future<void> markOnboarded() async {
    await _prefs.setBool(_kOnboarded, true);
    _emit(_current.copyWith(onboarded: true));
  }
}
