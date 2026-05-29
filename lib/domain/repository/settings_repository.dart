import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';

abstract class SettingsRepository {
  AppSettings get current;
  Stream<AppSettings> watch();
  Future<void> setLanguage(String tag);
  Future<void> setThemeMode(ThemeModePref mode);
  Future<void> setCurrency(String code);
  Future<void> setWeekStartDay(int day);
  Future<void> setBudgetStartDay(int day);
  Future<void> setDigitFormat(DigitFormat fmt);
  Future<void> markOnboarded();
  Future<void> load();
}
