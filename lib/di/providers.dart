import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_budget_manager/core/common/date_formatter.dart';
import 'package:expense_budget_manager/core/common/money_formatter.dart';
import 'package:expense_budget_manager/data/backup/backup_preferences.dart';
import 'package:expense_budget_manager/data/backup/backup_repository_impl.dart';
import 'package:expense_budget_manager/data/backup/google_auth_service.dart';
import 'package:expense_budget_manager/data/backup/google_drive_backup_client.dart';
import 'package:expense_budget_manager/data/backup/settings_snapshot.dart';
import 'package:expense_budget_manager/domain/backup/auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_repository.dart';
import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';
import 'package:expense_budget_manager/work/auto_backup.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart' show AppDatabase;
import 'package:expense_budget_manager/data/local/db/default_seeder.dart';
import 'package:expense_budget_manager/data/local/preferences/settings_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/account_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/budget_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/category_repository_impl.dart';
import 'package:expense_budget_manager/data/import/transaction_import_service.dart';
import 'package:expense_budget_manager/data/repository/debt_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/reminder_repository_impl.dart';
import 'package:expense_budget_manager/data/repository/transaction_repository_impl.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/domain/model/budget.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/debt.dart';
import 'package:expense_budget_manager/domain/model/transaction_with_details.dart';
import 'package:expense_budget_manager/domain/repository/account_repository.dart';
import 'package:expense_budget_manager/domain/repository/budget_repository.dart';
import 'package:expense_budget_manager/domain/repository/category_repository.dart';
import 'package:expense_budget_manager/domain/repository/debt_repository.dart';
import 'package:expense_budget_manager/domain/model/reminder.dart';
import 'package:expense_budget_manager/domain/repository/reminder_repository.dart';
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

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepositoryImpl(ref.watch(appDatabaseProvider));
});

final transactionImportServiceProvider = Provider<TransactionImportService>(
  (ref) => TransactionImportService(ref.watch(appDatabaseProvider)),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepositoryImpl(ref.watch(appDatabaseProvider)),
);

// ─── Google Sign-In + Drive backup ────────────────────────────────────────

final googleAuthServiceProvider =
    Provider<GoogleAuthService>((_) => GoogleAuthService());

final authServiceProvider =
    Provider<AuthService>((ref) => ref.watch(googleAuthServiceProvider));

/// Current signed-in user; updates on sign-in/out/account switch.
final authUserStreamProvider = StreamProvider(
  (ref) => ref.watch(authServiceProvider).watchUser(),
);

final backupPreferencesProvider = Provider<BackupPreferences>(
  (ref) => BackupPreferences(ref.watch(sharedPreferencesProvider)),
);

final driveBackupClientProvider = Provider<DriveBackupClient>(
  (ref) => GoogleDriveBackupClient(ref.watch(googleAuthServiceProvider)),
);

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(authServiceProvider),
    drive: ref.watch(driveBackupClientProvider),
    settingsStore:
        AppSettingsSnapshotStore(ref.watch(settingsRepositoryProvider)),
    prefs: ref.watch(backupPreferencesProvider),
    appVersion: () async {
      try {
        final info = await PackageInfo.fromPlatform();
        return '${info.version}+${info.buildNumber}';
      } catch (_) {
        return 'unknown';
      }
    },
  );
});

final autoBackupControllerProvider = Provider<AutoBackupController>((ref) {
  final controller = AutoBackupController(
    db: ref.watch(appDatabaseProvider),
    auth: ref.watch(googleAuthServiceProvider),
    repo: ref.watch(backupRepositoryProvider),
    prefs: ref.watch(backupPreferencesProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final remindersStreamProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchAll(),
);

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

final debtsStreamProvider = StreamProvider<List<DebtProgress>>(
  (ref) => ref.watch(debtRepositoryProvider).watchAll(),
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
