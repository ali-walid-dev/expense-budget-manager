/// Minimal identity of the signed-in user, decoupled from google_sign_in so
/// the auth provider could be swapped without touching business logic.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Stable provider account id — used to detect account switching. Never
  /// compare by email (emails can change).
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Authentication seam. Implementations must never log tokens; token storage
/// and refresh stay inside the provider SDK.
abstract class AuthService {
  /// The currently signed-in user, if any.
  AuthUser? get currentUser;

  /// Emits on every sign-in / sign-out / account switch.
  Stream<AuthUser?> watchUser();

  /// Interactive sign-in. Returns null when the user cancels the dialog
  /// (cancellation is not an error). Throws [BackupFailure] subtypes
  /// otherwise.
  Future<AuthUser?> signIn();

  /// Non-interactive re-authentication on app start. Never throws — returns
  /// null when no previous session can be resumed.
  Future<AuthUser?> signInSilently();

  /// Ends the local session. Must NOT delete any local data.
  Future<void> signOut();

  /// Revokes the app's access to the account entirely. Google may delete the
  /// appDataFolder contents as a consequence — callers must warn the user.
  Future<void> disconnect();
}
