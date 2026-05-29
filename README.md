# Expense Budget Manager

A local-first, offline Android personal-finance app built with **Flutter + Riverpod**.

Implements the spec in `TECHNICAL_DOCUMENTATION.md` — same Clean Architecture, same data model, same 13-phase build order — translated to Flutter idioms.

## Stack

- **Flutter / Dart** (UI + business logic, single codebase, native Android APK output)
- **Riverpod** (state + DI)
- **Drift** (type-safe SQLite, Room equivalent)
- **go_router** (navigation)
- **fl_chart** (analytics charts)
- **flutter_local_notifications** (offline notifications)
- **workmanager** (recurring transactions worker)
- **infinite_scroll_pagination** (Paging 3 equivalent)
- **google_fonts (Cairo)** (Arabic-friendly typography)
- **shared_preferences** (settings persistence)

See `TECHNICAL_DOCUMENTATION.md` for the full specification.

## Project layout

```
lib/
├── core/                 design system, common utils, navigation, l10n bridge
├── data/                 Drift DB, mappers, repository implementations
├── domain/               pure-Dart models, repository abstracts
├── features/             one folder per screen (notifier + state + UI)
├── work/                 workmanager + local notifications
├── di/                   Riverpod providers (DI container)
└── main.dart
```

## Build

The easiest way to get an APK is via the included **GitHub Actions** workflow (see `PUBLISH_AND_BUILD.md`). Manual local build instructions follow.

### Prerequisites (local build only)
- Flutter SDK ≥ 3.22 — https://docs.flutter.dev/get-started/install
- Android Studio (for the Android SDK + emulator)
- Java 17

Confirm with `flutter doctor`.

### One-time setup (local)
```powershell
flutter create . --platforms=android --org com.expensebudgetmanager --project-name expense_budget_manager
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

### Android manifest tweaks
After `flutter create`, edit `android/app/src/main/AndroidManifest.xml`:
1. Remove or do not add the `INTERNET` permission — the spec requires no internet.
2. Add:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
   ```
3. In `android/app/build.gradle.kts`, set `minSdk = 24` and enable core library desugaring.

### Run / build
```powershell
flutter run                   # on emulator
flutter build apk --release   # → build\app\outputs\flutter-apk\app-release.apk
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

## Smoke test
- Add a transaction (expense + income + transfer)
- Switch language to Arabic — RTL mirroring across the app
- Switch theme to Dark — every screen looks correct
- Create a budget; spend past it; verify the over-budget red state
- Open Analytics; switch period; pie + line chart populate
- Export CSV from Analytics — share sheet opens
- Airplane-mode the device — everything still works

## Architecture notes

- **Money is `int` minor units** end-to-end. The single `MoneyFormatter` (`lib/core/common/`) is the only place that formats it.
- **One immutable `UiState` per screen**, driven by a Riverpod `Notifier` / `AsyncNotifier`. Widgets never call repositories directly.
- **All strings via `.arb`** in `lib/l10n/`. Generated `AppLocalizations` is the only source of UI text.
- **Account balance is SQL-computed** — see `AccountDao.watchAllWithBalance`.
- **Analytics is SQL `SUM` / `GROUP BY`** — no Dart loops over results.
- **RTL**: `EdgeInsetsDirectional` / `AlignmentDirectional` everywhere — never `left`/`right`.

## Generated files (after `dart run build_runner build`)
- `lib/data/local/db/app_database.g.dart`
- `lib/data/local/db/daos.g.dart`
- `lib/l10n/generated/app_localizations*.dart`

These are gitignored.
