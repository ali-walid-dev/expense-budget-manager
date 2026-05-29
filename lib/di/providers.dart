import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_budget_manager/core/common/date_formatter.dart';
import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart' show AppDatabase;
import 'package:expense_budget_manager/data/local/db/default_seeder.dart';
import 'package:expense_budget_manager/data/local/preferences/settings_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/account_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/budget_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/category_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/transaction_repository_impl.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';
import 'package:expense_budget_manager/domain/repository/account_repository.dart';
import 'package:expense_budget_manager/domain/repository/budget_repository.dart';
import 'package:expense_budget_manager/domain/repository/category_repository.dart';
import 'package:expense_budget_manager/domain/repository/settings_repository.dart';
import 'package:expense_budget_manager/domain/repository/transaction_repository.dart';

// ─── Bootstrapping ────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override in main()'),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

// ─── Repositories ─────────────────────────────────────────────────────────

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(ref.watch(appDatabaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(appDatabaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(appDatabaseProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

// ─── Settings + Formatters ────────────────────────────────────────────────

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    final sub = repo.watch().listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return repo.current;
  }

  Future<void> setLanguage(String tag) =>
      ref.read(settingsRepositoryProvider).setLanguage(tag);
  Future<void> setThemeMode(ThemeModePref mode) =>
      ref.read(settingsRepositoryProvider).setThemeMode(mode);
  Future<void> setCurrency(String code) =>
      ref.read(settingsRepositoryProvider).setCurrency(code);
  Future<void> setWeekStartDay(int day) =>
      ref.read(settingsRepositoryProvider).setWeekStartDay(day);
  Future<void> setBudgetStartDay(int day) =>
      ref.read(settingsRepositoryProvider).setBudgetStartDay(day);
  Future<void> setDigitFormat(DigitFormat fmt) =>
      ref.read(settingsRepositoryProvider).setDigitFormat(fmt);
  Future<void> markOnboarded() =>
      ref.read(settingsRepositoryProvider).markOnboarded();
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  final s = ref.watch(settingsProvider);
  return MoneyFormatter(
    currencyCode: s.currency,
    digitFormat: s.digitFormat,
    locale: s.languageTag,
  );
});

final dateFormatterProvider = Provider<DateFormatter>((ref) {
  final s = ref.watch(settingsProvider);
  return DateFormatter(localeTag: s.languageTag, digitFormat: s.digitFormat);
});

// ─── Stream conveniences for UI ───────────────────────────────────────────

final accountsStreamProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

final accountsWithBalanceStreamProvider =
    StreamProvider<List<AccountWithBalance>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAllWithBalance(),
);

final accountDetailStreamProvider = StreamProvider.family<
    AccountWithBalanceAndTransactions, int>(
  (ref, id) => ref
      .watch(accountRepositoryProvider)
      .watchOneDetail(id)
      .where((e) => e != null)
      .cast<AccountWithBalanceAndTransactions>(),
);

final categoryTreeStreamProvider = StreamProvider<List<CategoryNode>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchTree(),
);

final allExpenseCategoriesStreamProvider = StreamProvider<List<Category>>(
  (ref) => ref
      .watch(categoryRepositoryProvider)
      .watchByType(CategoryType.expense),
);

final allCategoriesStreamProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

final budgetsStreamProvider = StreamProvider<List<BudgetProgress>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchProgress(),
);

final transactionStreamSignalProvider = StreamProvider<int>(
  (ref) => ref.watch(transactionRepositoryProvider).watchChangeSignal(),
);

final searchStreamProvider =
    StreamProvider.family<List<TransactionWithDetails>, String>(
  (ref, q) => ref.watch(transactionRepositoryProvider).search(q),
);

// ─── One-shot seed ────────────────────────────────────────────────────────

final seedDataProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await DefaultSeeder(db).seedIfEmpty();
});
