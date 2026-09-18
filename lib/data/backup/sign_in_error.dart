import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// Maps a platform sign-in error onto a typed [BackupFailure].
///
/// The Android plugin reports almost every problem as the single code
/// `sign_in_failed`, hiding the actual Google Play Services status in the
/// message (`ApiException: 10: `). Collapsing all of those into one generic
/// "sign-in failed" message is why a signing-configuration problem looked to
/// the user like the account picker closing by itself.
///
/// The returned failure always carries the raw code/status in `detail` so the
/// UI can show something actionable.
BackupFailure classifySignInError({required String code, String? message}) {
  final status = _statusCode(message);
  final detail = status == null ? code : '$code / $status';
  final text = (message ?? '').toLowerCase();

  // Explicit plugin codes first — they are unambiguous.
  switch (code) {
    case 'sign_in_canceled':
    case 'sign_in_cancelled':
      return const SignInCancelled();
    case 'network_error':
      return NetworkFailure(detail);
  }

  if (text.contains('access_denied')) {
    return ConsentDeniedFailure(detail);
  }

  // Google Play Services `CommonStatusCodes` hidden inside the message.
  switch (status) {
    case 10: // DEVELOPER_ERROR — unregistered SHA-1 / package name.
      return SignInConfigurationFailure(detail);
    case 7: // NETWORK_ERROR
      return NetworkFailure(detail);
    case 12501: // SIGN_IN_CANCELLED — the user dismissed the picker.
      return const SignInCancelled();
  }

  return AuthFailure(detail);
}

/// Extracts the numeric Play Services status from a plugin message such as
/// `com.google.android.gms.common.api.ApiException: 10: `, or a bare `10`.
int? _statusCode(String? message) {
  if (message == null) return null;
  // Prefer the anchored form so an unrelated number elsewhere in the message
  // (a version, a package fragment) can never be mistaken for a status.
  final anchored = RegExp(r'ApiException:\s*(\d+)').firstMatch(message);
  if (anchored != null) return int.tryParse(anchored.group(1)!);
  final bare = RegExp(r'^\s*(\d+)\s*$').firstMatch(message);
  return bare == null ? null : int.tryParse(bare.group(1)!);
}
