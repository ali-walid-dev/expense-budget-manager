import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_budget_manager/core/design_system/app_theme.dart';
import 'package:expense_budget_manager/core/navigation/app_router.dart';
import 'package:expense_budget_manager/data/local/preferences/settings_repository_impl.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/app_settings.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';
import 'package:expense_budget_manager/work/background_worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Bootstrap settings synchronously so SettingsRepository.current works at startup.
  final settingsRepo = SettingsRepositoryImpl(prefs);
  await settingsRepo.load();

  // Background worker for recurring transactions. Wrapped in try/catch so
  // failure (e.g. unsupported platform) doesn't kill the app launch.
  try {
    await initBackgroundWorker();
  } catch (_) {}

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
    ],
  );
  // Idempotent seed (skips if categories already exist).
  await container.read(seedDataProvider.future);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const App(),
  ));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
          theme: AppTheme.light(dynamicScheme: lightDynamic),
          darkTheme: AppTheme.dark(dynamicScheme: darkDynamic),
          themeMode: switch (settings.themeMode) {
            ThemeModePref.system => ThemeMode.system,
            ThemeModePref.light => ThemeMode.light,
            ThemeModePref.dark => ThemeMode.dark,
          },
          locale: Locale(settings.languageTag),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        );
      },
    );
  }
}
