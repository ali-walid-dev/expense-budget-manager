import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

import 'package:expense_budget_manager/data/backup/sign_in_error.dart';
import 'package:expense_budget_manager/domain/backup/auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';

/// google_sign_in (6.x API) implementation.
///
/// Scopes: basic email/profile + drive.appdata ONLY — backups live in the
/// hidden appDataFolder, private to this app and invisible in the user's
/// Drive UI. Full Drive access is never requested.
class GoogleAuthService implements AuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
      : _google = googleSignIn ??
            GoogleSignIn(scopes: const [
              'email',
              'https://www.googleapis.com/auth/drive.appdata',
            ]);

  final GoogleSignIn _google;

  @override
  AuthUser? get currentUser => _toUser(_google.currentUser);

  @override
  Stream<AuthUser?> watchUser() => _google.onCurrentUserChanged.map(_toUser);

  @override
  Future<AuthUser?> signIn() async {
    try {
      final account = await _google.signIn();
      return _toUser(account); // null == user cancelled (Android contract)
    } on PlatformException catch (e) {
      // The Android plugin hides the real Play Services status inside the
      // message, so classify on both. Reporting every failure as a generic
      // AuthFailure is what made a signing-configuration problem look like
      // the account picker closing by itself.
      final failure = classifySignInError(code: e.code, message: e.message);
      if (failure is SignInCancelled) return null;
      throw failure;
    }
  }

  @override
  Future<AuthUser?> signInSilently() async {
    try {
      return _toUser(await _google.signInSilently(suppressErrors: true));
    } catch (_) {
      return null; // silent re-auth must never surface errors
    }
  }

  @override
  Future<void> signOut() => _google.signOut();

  @override
  Future<void> disconnect() async {
    try {
      await _google.disconnect();
    } on PlatformException catch (e) {
      throw AuthFailure(e.code);
    }
  }

  /// Authenticated HTTP client for googleapis calls. Built fresh per
  /// operation; null when not signed in. Tokens stay inside the SDK and are
  /// never logged.
  Future<gauth.AuthClient?> apiClient() => _google.authenticatedClient();

  /// Forces a token refresh after a 401 — returns true when a usable session
  /// exists again.
  Future<bool> refreshSession() async {
    try {
      final account =
          await _google.signInSilently(reAuthenticate: true, suppressErrors: true);
      return account != null;
    } catch (_) {
      return false;
    }
  }

  AuthUser? _toUser(GoogleSignInAccount? a) => a == null
      ? null
      : AuthUser(
          id: a.id,
          email: a.email,
          displayName: a.displayName,
          photoUrl: a.photoUrl,
        );
}
