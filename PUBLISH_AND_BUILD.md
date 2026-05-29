# How to get your APK via GitHub Actions

A workflow at `.github/workflows/build-apk.yml` builds the APK in the cloud. You just need to push the repo to GitHub.

## One-time setup

### 1. Create a GitHub repo
Go to https://github.com/new and create a new private (or public) repo. **Don't** add a README, .gitignore, or license — leave it empty.

### 2. Push the code from your machine

Open PowerShell in `E:\external\expense-budget-manager` and run:

```powershell
git init
git add .
git commit -m "Initial commit: Flutter expense budget manager"
git branch -M main
git remote add origin https://github.com/<YOUR-USERNAME>/<YOUR-REPO>.git
git push -u origin main
```

GitHub will prompt for credentials. Use a [Personal Access Token](https://github.com/settings/tokens) (classic, with `repo` scope) as the password if HTTPS asks for one.

### 3. Watch the build

Go to `https://github.com/<YOUR-USERNAME>/<YOUR-REPO>/actions` — the **Build Android APK** workflow will start automatically. It takes ~6-10 minutes.

When it finishes, scroll down on the run page to the **Artifacts** section. Download `expense-budget-manager-release.apk.zip`, unzip it, and you have your APK.

### 4. Install on your phone

Either:
- USB: `adb install -r app-release.apk`
- Sideload: copy the APK to your phone, tap it, allow "Install from unknown sources" if prompted

## Triggering manual builds

After the first push, you can manually trigger builds:
1. Go to **Actions** → **Build Android APK** → **Run workflow**
2. Pick `release`, `debug`, or `profile` mode
3. Click **Run workflow**

## What the workflow does

In CI it sets up Java 17 + Flutter stable, scaffolds the `android/` folder with `flutter create`, patches the `AndroidManifest.xml` (adds notification permissions, strips INTERNET per the spec) and `build.gradle.kts` (minSdk 24, core library desugaring), runs `pub get` + `build_runner` + `gen-l10n`, then `flutter build apk --release`. The APK is uploaded as an artifact.

## If the build fails

Pull up the failed step's log on GitHub. Most likely first-build issues:

- **Dependency resolution conflict** — A package's pinned version doesn't match Flutter stable's Dart SDK. Fix: update `pubspec.yaml` upper bounds or run `flutter pub upgrade --major-versions` locally and commit the new `pubspec.yaml`.
- **Drift codegen error** — Usually a typo in a custom SQL query in `lib/data/local/db/daos.dart`. Error message names the file + line.
- **AndroidManifest patch didn't match** — Flutter's template may have changed slightly. The `sed` lines in the workflow need adjusting.
- **`build_runner` complains about missing part** — Re-run the workflow; sometimes the `.g.dart` files need a second pass after l10n generates.

Share the failing log with me in a new session and I'll fix it.
