# Google Sign-In Setup Checklist

Google Sign-In cannot be fixed from code alone. Google Play Services authorises
the app by matching two things against an **OAuth client** you register in the
Google Cloud Console:

1. the **package name** of the installed app, and
2. the **SHA-1 fingerprint of the key that signed the APK**.

If either does not match a registered client, the account picker opens, you
choose an account, and the sign-in then fails with `ApiException: 10`
(`DEVELOPER_ERROR`) — which, before this change, surfaced as a generic message
and looked like the picker had simply closed by itself.

Work through this checklist in order. Every step is required.

---

## The values you need

| What | Value |
|------|-------|
| Package name | `com.expensebudgetmanager.expense_budget_manager` |
| Required scope | `https://www.googleapis.com/auth/drive.appdata` |

The package name comes from the CI workflow's
`flutter create --org com.expensebudgetmanager --project-name expense_budget_manager`
and must be typed into the Console **exactly** as above.

---

## Step 1 — Create a stable signing key

This is the step most likely to be missing. GitHub Actions runners generate a
**fresh debug keystore on every run**, so an APK built without the signing
secrets has a different SHA-1 each time — a fingerprint that can never be
registered. Sign-in can never work in such a build.

Create the keystore once, on your own machine, and keep it safe (losing it
means you can never update an app already published under it):

```bash
keytool -genkey -v -keystore release.keystore \
  -alias app -keyalg RSA -keysize 2048 -validity 10000
```

Read its fingerprints:

```bash
keytool -list -v -alias app -keystore release.keystore
```

Copy the **SHA1** and **SHA256** lines from the output. You need the SHA-1 for
Step 3.

## Step 2 — Add the keystore to GitHub as secrets

Encode the keystore:

```bash
base64 -w0 release.keystore      # Linux / Git Bash
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Set-Clipboard
```

Then in the repository: **Settings → Secrets and variables → Actions → New
repository secret**, and add all four:

| Secret name | Value |
|-------------|-------|
| `ANDROID_KEYSTORE_BASE64` | the base64 string from above |
| `ANDROID_KEYSTORE_PASSWORD` | the store password you chose |
| `ANDROID_KEY_ALIAS` | `app` |
| `ANDROID_KEY_PASSWORD` | the key password you chose |

These names are exactly what [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml)
reads. With them present, the workflow writes `android/key.properties` and
signs the release APK with your stable key. Without `ANDROID_KEYSTORE_BASE64`
the build still succeeds but logs:

```
No ANDROID_KEYSTORE_BASE64 secret - release stays on the ephemeral debug key
(Google Sign-In will NOT work in this APK).
```

If you see that line in a build log, sign-in in that APK is guaranteed to fail.

## Step 3 — Google Cloud Console

1. Create or open a project at <https://console.cloud.google.com>.
2. **Enable the Drive API**: APIs & Services → Library → search "Google Drive
   API" → **Enable**.
3. **OAuth consent screen**: APIs & Services → OAuth consent screen →
   **External** → fill in app name and support email.
   - Add the scope `https://www.googleapis.com/auth/drive.appdata`.
   - While the app is in **Testing** mode, add every Google account you intend
     to sign in with under **Test users**. An account that is not listed is
     rejected with `access_denied`, no matter how correct the signing key is.
4. **Create the Android OAuth client**: APIs & Services → Credentials →
   Create credentials → OAuth client ID → Application type **Android**.
   - Package name: `com.expensebudgetmanager.expense_budget_manager`
   - SHA-1: the fingerprint from Step 1.

No client ID is embedded in the app. On Android, Google matches the request by
package name + signing fingerprint alone, so there is nothing to paste back
into the code.

## Step 4 — One OAuth client per signing key

A client authorises exactly one fingerprint. Create an additional Android OAuth
client (same package name, different SHA-1) for each key you use:

- **Your local debug builds** are signed with `~/.android/debug.keystore`:

  ```bash
  keytool -list -v -alias androiddebugkey \
    -keystore ~/.android/debug.keystore -storepass android
  ```

- **Google Play App Signing**: when you publish through Play, Google re-signs
  the app with its own key, so the fingerprint changes again. Copy the SHA-1
  from Play Console → Setup → App integrity → App signing, and register it too.
  Sign-in working in your CI APK does **not** mean it will work in the Play
  build unless you do this.

---

## Verifying

Install a release APK built **after** the secrets were added, and try to sign
in. The app now reports the underlying platform error code instead of a generic
message, so a failure tells you which step to revisit:

| Message shown in the app | What it means | Fix |
|--------------------------|---------------|-----|
| `DEVELOPER_ERROR` / code `10` | The APK's SHA-1 + package name are not registered | Steps 1–4. Confirm the build log did **not** print the ephemeral-key warning, and that the SHA-1 you registered is the one from the key that actually signed this APK. |
| `access_denied` | The consent screen rejected the account | Step 3.3 — add the account under Test users, and confirm the `drive.appdata` scope is listed. |
| `network_error` | No connectivity reaching Google | Check the device's network. `INTERNET` permission is added by the CI workflow. |
| `sign_in_required` / picker closes with no error | The sign-in was genuinely cancelled | Nothing to fix — retry and complete the picker. |

Changes in the Cloud Console can take a few minutes to propagate. If a newly
registered SHA-1 still fails, wait and retry before changing anything else.
