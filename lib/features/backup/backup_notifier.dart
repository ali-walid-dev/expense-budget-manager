import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/backup/auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_repository.dart';
import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';

enum BackupBusy { none, signingIn, checking, backingUp, restoring }

class BackupState {
  const BackupState({
    required this.user,
    required this.autoBackup,
    required this.lastBackupAt,
    required this.lastBackupSizeBytes,
    required this.busy,
  });

  final AuthUser? user;
  final bool autoBackup;
  final DateTime? lastBackupAt;
  final int? lastBackupSizeBytes;
  final BackupBusy busy;

  BackupState copyWith({
    Object? user = _sentinel,
    bool? autoBackup,
    Object? lastBackupAt = _sentinel,
    Object? lastBackupSizeBytes = _sentinel,
    BackupBusy? busy,
  }) =>
      BackupState(
        user: user == _sentinel ? this.user : user as AuthUser?,
        autoBackup: autoBackup ?? this.autoBackup,
        lastBackupAt: lastBackupAt == _sentinel
            ? this.lastBackupAt
            : lastBackupAt as DateTime?,
        lastBackupSizeBytes: lastBackupSizeBytes == _sentinel
            ? this.lastBackupSizeBytes
            : lastBackupSizeBytes as int?,
        busy: busy ?? this.busy,
      );

  static const _sentinel = Object();
}

/// State + actions for the Backup & Sync screen. Methods rethrow
/// [BackupFailure] subtypes — the screen maps them to localized messages and
/// drives the dialogs (fresh-restore prompt, account conflict).
class BackupNotifier extends AsyncNotifier<BackupState> {
  @override
  Future<BackupState> build() async {
    // Rebuild when the signed-in account changes (silent sign-in completing,
    // sign-out from elsewhere, account switch).
    final streamUser = ref.watch(authUserStreamProvider).valueOrNull;
    final auth = ref.watch(authServiceProvider);
    final prefs = ref.watch(backupPreferencesProvider);
    return BackupState(
      user: streamUser ?? auth.currentUser,
      autoBackup: prefs.autoBackupEnabled,
      lastBackupAt: prefs.lastBackupAt,
      lastBackupSizeBytes: prefs.lastBackupSizeBytes,
      busy: BackupBusy.none,
    );
  }

  void _set(BackupState s) => state = AsyncData(s);

  /// Interactive sign-in. Returns null if the user cancelled, otherwise the
  /// post-sign-in classification for the screen to act on.
  Future<PostSignInCheck?> signIn() async {
    final s = state.value!;
    _set(s.copyWith(busy: BackupBusy.signingIn));
    try {
      final user = await ref.read(authServiceProvider).signIn();
      if (user == null) {
        _set(s.copyWith(busy: BackupBusy.none));
        return null; // cancelled — soft notice only
      }
      _set(s.copyWith(user: user, busy: BackupBusy.checking));
      final check = await ref.read(backupRepositoryProvider).checkAfterSignIn();
      _set(state.value!.copyWith(user: user, busy: BackupBusy.none));
      return check;
    } catch (_) {
      _set(state.value!.copyWith(busy: BackupBusy.none));
      rethrow;
    }
  }

  Future<BackupResult> backupNow() async {
    _set(state.value!.copyWith(busy: BackupBusy.backingUp));
    try {
      final result = await ref.read(backupRepositoryProvider).backupNow();
      final prefs = ref.read(backupPreferencesProvider);
      _set(state.value!.copyWith(
        busy: BackupBusy.none,
        lastBackupAt: prefs.lastBackupAt,
        lastBackupSizeBytes: prefs.lastBackupSizeBytes,
      ));
      return result;
    } catch (_) {
      _set(state.value!.copyWith(busy: BackupBusy.none));
      rethrow;
    }
  }

  Future<void> restore({RemoteBackup? from}) async {
    _set(state.value!.copyWith(busy: BackupBusy.restoring));
    try {
      await ref.read(backupRepositoryProvider).restore(from: from);
      _set(state.value!.copyWith(busy: BackupBusy.none));
    } catch (_) {
      _set(state.value!.copyWith(busy: BackupBusy.none));
      rethrow;
    }
  }

  Future<RemoteBackup?> latestCloudBackup() =>
      ref.read(backupRepositoryProvider).latestCloudBackup();

  Future<int> localTransactionCount() =>
      ref.read(backupRepositoryProvider).localTransactionCount();

  Future<void> setAutoBackup(bool enabled) async {
    await ref.read(backupPreferencesProvider).setAutoBackupEnabled(enabled);
    _set(state.value!.copyWith(autoBackup: enabled));
  }

  /// Sign out keeps ALL local data — it only ends the session.
  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    _set(state.value!.copyWith(user: null, busy: BackupBusy.none));
  }

  /// Revokes access entirely. Local data is kept; Google may delete the
  /// appDataFolder backups (the screen warns before calling this).
  Future<void> disconnect() async {
    await ref.read(authServiceProvider).disconnect();
    _set(state.value!.copyWith(user: null, busy: BackupBusy.none));
  }
}

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
