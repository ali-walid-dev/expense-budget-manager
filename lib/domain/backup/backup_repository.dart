import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';

/// Outcome of a completed backup.
class BackupResult {
  const BackupResult({required this.createdAt, required this.sizeBytes});
  final DateTime createdAt;
  final int sizeBytes;
}

/// What the app should do right after a sign-in completes.
sealed class PostSignInCheck {
  const PostSignInCheck();
}

/// Nothing to decide. [cloudBackup] is non-null when a backup exists and
/// belongs to this account's normal flow (same account, local data present).
class PostSignInNone extends PostSignInCheck {
  const PostSignInNone({this.cloudBackup});
  final RemoteBackup? cloudBackup;
}

/// Fresh install: local data is empty and a cloud backup exists — offer to
/// restore it.
class PostSignInPromptRestore extends PostSignInCheck {
  const PostSignInPromptRestore(this.cloudBackup);
  final RemoteBackup cloudBackup;
}

/// Local data exists AND a cloud backup exists for an account that is not the
/// one this device's data is bound to. The user must choose explicitly; no
/// side is overwritten silently.
class PostSignInConflict extends PostSignInCheck {
  const PostSignInConflict({required this.cloudBackup, required this.localTransactionCount});
  final RemoteBackup cloudBackup;
  final int localTransactionCount;
}

/// Orchestrates serialize -> compress -> (encrypt) -> upload and the reverse.
/// All methods throw [BackupFailure] subtypes on error.
abstract class BackupRepository {
  /// Serializes the full dataset and uploads it. Returns the new backup info.
  Future<BackupResult> backupNow();

  /// Newest cloud backup, or null when none exists.
  Future<RemoteBackup?> latestCloudBackup();

  /// Downloads, validates, and applies [from] (or the newest backup when
  /// null). Atomic: a failure leaves local data exactly as it was.
  Future<void> restore({RemoteBackup? from});

  /// Count of user transactions on this device — the "is this a fresh
  /// install" heuristic (default categories/accounts are seeded, so table
  /// emptiness overall is not meaningful).
  Future<int> localTransactionCount();

  /// Classifies the situation right after a sign-in (fresh install / account
  /// conflict / nothing to do).
  Future<PostSignInCheck> checkAfterSignIn();
}
