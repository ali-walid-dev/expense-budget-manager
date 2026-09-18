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
1. Add:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
   <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
   ```
   > `INTERNET` is required only for the optional Google Drive backup; every
   > other feature works fully offline.
2. In `android/app/build.gradle.kts`, set `minSdk = 24` and enable core library desugaring.

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

---

## Google Sign-In & Drive Backup

Optional feature: sign in with Google and back up **all data** (transactions,
accounts, categories, budgets, debts, reminders, recurring rules, tags, and
settings) to the user's own Google Drive — stored in the hidden
**appDataFolder** (scope `drive.appdata` only; the app never sees the rest of
the user's Drive, and backups are invisible in the Drive UI). On a fresh
install, signing in detects the backup and offers a full restore.

The app remains 100% functional without ever signing in. **Note:** this
feature relaxes the original "no INTERNET permission" constraint in
`TECHNICAL_DOCUMENTATION.md` §10 — the permission is now added by the CI
workflow.

### One-time Google Cloud Console setup (cannot be done from code)

1. Create (or reuse) a project at https://console.cloud.google.com.
2. **Enable the Google Drive API**: APIs & Services → Library → "Google Drive
   API" → Enable.
3. **OAuth consent screen**: APIs & Services → OAuth consent screen →
   External → fill app name/support email. Add the scope
   `https://www.googleapis.com/auth/drive.appdata`. While in *Testing* mode,
   add your Google account under **Test users** (otherwise sign-in is blocked
   with `access_denied`).
4. **Android OAuth client**: APIs & Services → Credentials → Create
   credentials → OAuth client ID → Android:
   - Package name: `com.expensebudgetmanager.expense_budget_manager`
   - SHA-1: the fingerprint of the key that signs the APK you test (see below).
   Create one client per signing key you use (debug + release).

No client ID needs to be embedded in the app for Android — Google matches the
package name + signing SHA-1 at runtime.

### Signing keys & SHA-1 (the #1 cause of "works in debug, fails in release")

Google Sign-In fails with `DEVELOPER_ERROR` / status code 10 when the APK's
signing SHA-1 is not registered:

- **Local debug builds** are signed with `~/.android/debug.keystore`. Get its
  SHA-1 with:
  `keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`
- **CI builds**: GitHub runners generate a *fresh* debug keystore every run,
  so an unsigned-secrets CI APK can never pass Google Sign-In. Create a stable
  keystore once and add it as repo secrets:
  ```bash
  keytool -genkey -v -keystore release.keystore -alias app -keyalg RSA -keysize 2048 -validity 10000
  keytool -list -v -alias app -keystore release.keystore        # note the SHA-1 + SHA-256
  base64 -w0 release.keystore                                   # -> ANDROID_KEYSTORE_BASE64
  ```
  Repo secrets consumed by the workflow: `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
  Register that SHA-1 (and SHA-256) in the Android OAuth client.
- **Play App Signing**: if you later publish via Google Play, Play re-signs
  the app with *its own* key. Copy the SHA-1 from Play Console → Setup → App
  integrity → App signing, and add it as another Android OAuth client.

### iOS (not currently scaffolded in this repo)

When an `ios/` folder is added: create an **iOS OAuth client** (bundle id),
then in `ios/Runner/Info.plist` add `GIDClientID` (the iOS client ID) and a
URL scheme equal to the *reversed* client ID
(`com.googleusercontent.apps.xxxx`). No other code changes are needed — the
Dart layer is platform-neutral.

### How backups are stored

- Single gzip-compressed JSON document per backup:
  `{schemaVersion, appVersion, createdAt, deviceInfo, data:{dbSchemaVersion, transactions, configurations, settings}}`.
- Uploaded as `backup_<timestamp>.json.gz` to `appDataFolder`; the **3 newest**
  backups are kept, older ones pruned (a corrupted upload can never destroy
  the previous good backup).
- Restore is **atomic** — one SQLite transaction with deferred FK checks; any
  validation/IO failure rolls back and local data is untouched.
- `appLockEnabled` is deliberately **not** backed up (device-local security).
- Optional at-rest encryption is stubbed behind `BackupCipher` (AES-GCM can be
  added later without touching repository/UI code).

### Manual OAuth test checklist

1. Sign in → Back up now → uninstall → reinstall → sign in → restore prompt →
   data identical (transactions, budgets, debts, reminders, settings, theme,
   language).
2. Cancel the sign-in dialog → soft "Sign-in cancelled" notice, app continues.
3. Airplane mode → Back up now → "No internet connection" message; auto-backup
   queues silently and retries next launch.
4. Restore with a corrupted cloud file → clear error, local data untouched.
5. Device with data from account A → sign in with account B → conflict dialog
   (keep device / restore cloud / decide later); nothing changes silently.
6. 10,000+ transactions → backup/restore complete with a responsive UI.
7. Leave the app signed in for >1h (token expiry) → backup still succeeds
   (silent refresh) or asks to re-authenticate; never crashes.
8. Restore a backup whose schema is newer than the app → "created by a newer
   version" message.
9. Sign out → all local data still present.
