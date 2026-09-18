/// Typed failures for the Google Drive backup stack. Every auth/Drive/codec
/// error is mapped onto one of these so the UI can show a human-readable,
/// localized message — raw exceptions never reach the user.
sealed class BackupFailure implements Exception {
  const BackupFailure([this.detail]);

  /// Developer-facing detail. Never shown to the user, never contains tokens
  /// or backup contents.
  final String? detail;

  @override
  String toString() => '$runtimeType(${detail ?? ''})';
}

/// No connectivity / transient transport error after retries.
class NetworkFailure extends BackupFailure {
  const NetworkFailure([super.detail]);
}

/// Not signed in, consent revoked, or token refresh failed.
class AuthFailure extends BackupFailure {
  const AuthFailure([super.detail]);
}

/// The user cancelled the sign-in dialog. A soft notice, not an error.
class SignInCancelled extends BackupFailure {
  const SignInCancelled() : super();
}

/// Google Drive storage quota exhausted (or rate limited beyond retry).
class QuotaFailure extends BackupFailure {
  const QuotaFailure([super.detail]);
}

/// The backup file is structurally invalid: bad gzip, bad JSON, missing
/// required keys, or rows that don't match the local schema.
class CorruptBackupFailure extends BackupFailure {
  const CorruptBackupFailure([super.detail]);
}

/// Backup was produced by a newer app (envelope or DB schema ahead of ours).
class UnsupportedVersionFailure extends BackupFailure {
  const UnsupportedVersionFailure({required this.found, required this.supported})
      : super('found $found, supported <= $supported');
  final int found;
  final int supported;
}

/// No backup exists in the account's appDataFolder.
class NoBackupFailure extends BackupFailure {
  const NoBackupFailure() : super();
}

/// Anything not classified above. [cause] kept for logs only.
class UnknownBackupFailure extends BackupFailure {
  const UnknownBackupFailure(this.cause) : super();
  final Object cause;

  @override
  String toString() => 'UnknownBackupFailure($cause)';
}

/// Google rejected the app itself, not the account: the APK's signing SHA-1 +
/// package name are not registered as an Android OAuth client
/// (`DEVELOPER_ERROR`, status 10). The account picker opens and then fails, so
/// this is reported separately from a generic [AuthFailure] — the fix is in the
/// Google Cloud Console, not in the app. See GOOGLE_SIGNIN_SETUP.md.
class SignInConfigurationFailure extends BackupFailure {
  const SignInConfigurationFailure([super.detail]);
}

/// The OAuth consent screen refused the account — typically a project still in
/// *Testing* mode with the account missing from its Test users list.
class ConsentDeniedFailure extends BackupFailure {
  const ConsentDeniedFailure([super.detail]);
}
