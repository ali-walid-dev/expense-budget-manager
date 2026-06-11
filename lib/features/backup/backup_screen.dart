import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/backup/auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';
import 'package:expense_budget_manager/domain/backup/backup_repository.dart';
import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';
import 'package:expense_budget_manager/features/backup/backup_notifier.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// Raw exceptions never reach the user — every failure maps to a localized
  /// message.
  String _failureText(AppLocalizations l, Object e) => switch (e) {
        NetworkFailure() => l.errNetwork,
        AuthFailure() => l.errAuth,
        SignInCancelled() => l.signInCancelled,
        QuotaFailure() => l.errQuota,
        CorruptBackupFailure() => l.errCorruptBackup,
        UnsupportedVersionFailure() => l.errUnsupportedBackup,
        NoBackupFailure() => l.errNoBackup,
        _ => l.errUnknown,
      };

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    final l = AppLocalizations.of(context)!;
    try {
      final check =
          await ref.read(backupNotifierProvider.notifier).signIn();
      if (check == null) {
        _toast(l.signInCancelled); // soft notice, app continues normally
        return;
      }
      if (!mounted) return;
      switch (check) {
        case PostSignInPromptRestore(:final cloudBackup):
          await _promptFreshRestore(cloudBackup);
        case PostSignInConflict(:final cloudBackup, :final localTransactionCount):
          await _promptConflict(cloudBackup, localTransactionCount);
        case PostSignInNone(:final cloudBackup):
          if (cloudBackup == null) _toast(l.noBackupFound);
      }
    } catch (e) {
      _toast(_failureText(AppLocalizations.of(context)!, e));
    }
  }

  /// Fresh install: local data empty, cloud backup found.
  Future<void> _promptFreshRestore(RemoteBackup cloud) async {
    final l = AppLocalizations.of(context)!;
    final dateF = ref.read(dateFormatterProvider);
    final when =
        cloud.createdAt == null ? '—' : dateF.dateTime(cloud.createdAt!.toLocal());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.restoreBackupTitle),
        content: Text(l.backupFoundBody(when)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.decideLater)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.restoreAction)),
        ],
      ),
    );
    if (ok == true) await _doRestore(from: cloud);
  }

  /// Local data + cloud backup from a different account: explicit choice, no
  /// silent overwrite in either direction.
  Future<void> _promptConflict(RemoteBackup cloud, int localCount) async {
    final l = AppLocalizations.of(context)!;
    final dateF = ref.read(dateFormatterProvider);
    final when =
        cloud.createdAt == null ? '—' : dateF.dateTime(cloud.createdAt!.toLocal());
    final choice = await showDialog<_ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(l.conflictTitle),
        content: Text(l.conflictBody(localCount, when)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ConflictChoice.later),
            child: Text(l.decideLater),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ConflictChoice.keepDevice),
            child: Text(l.keepDeviceData),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, _ConflictChoice.restoreCloud),
            child: Text(l.restoreCloudBackup),
          ),
        ],
      ),
    );
    switch (choice) {
      case _ConflictChoice.keepDevice:
        await _doBackup(); // device wins -> cloud is overwritten, explicitly
      case _ConflictChoice.restoreCloud:
        await _doRestore(from: cloud);
      case _ConflictChoice.later || null:
        break;
    }
  }

  Future<void> _doBackup() async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(backupNotifierProvider.notifier).backupNow();
      _toast(l.backupDone);
    } catch (e) {
      _toast(_failureText(l, e));
    }
  }

  Future<void> _doRestore({RemoteBackup? from}) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(backupNotifierProvider.notifier).restore(from: from);
      _toast(l.restoreDone);
    } catch (e) {
      _toast(_failureText(l, e));
    }
  }

  /// "Restore from backup" button: confirm (with replace warning when local
  /// data exists) before applying.
  Future<void> _restorePressed() async {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(backupNotifierProvider.notifier);
    try {
      final cloud = await notifier.latestCloudBackup();
      if (cloud == null) {
        _toast(l.errNoBackup);
        return;
      }
      if (!mounted) return;
      final localCount = await notifier.localTransactionCount();
      if (!mounted) return;
      final dateF = ref.read(dateFormatterProvider);
      final when = cloud.createdAt == null
          ? '—'
          : dateF.dateTime(cloud.createdAt!.toLocal());
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l.restoreBackupTitle),
          content: Text(localCount > 0
              ? '${l.backupFoundBody(when)}\n\n${l.restoreReplaceWarning}'
              : l.backupFoundBody(when)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel)),
            FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.restoreAction)),
          ],
        ),
      );
      if (ok == true) await _doRestore(from: cloud);
    } catch (e) {
      _toast(_failureText(l, e));
    }
  }

  Future<void> _signOut() async {
    // Signing out never deletes device data.
    await ref.read(backupNotifierProvider.notifier).signOut();
  }

  Future<void> _disconnect() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.disconnectAccount),
        content: Text(l.disconnectWarning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.disconnectAccount)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(backupNotifierProvider.notifier).disconnect();
    } catch (e) {
      _toast(_failureText(AppLocalizations.of(context)!, e));
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(backupNotifierProvider);
    final dateF = ref.watch(dateFormatterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.backupAndSync)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_failureText(l, e))),
        data: (s) {
          final busyLabel = switch (s.busy) {
            BackupBusy.signingIn || BackupBusy.checking => l.checkingForBackup,
            BackupBusy.backingUp => l.backingUp,
            BackupBusy.restoring => l.restoring,
            BackupBusy.none => null,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AccountCard(
                user: s.user,
                busy: s.busy != BackupBusy.none,
                onSignIn: _signIn,
                onSignOut: _signOut,
                onDisconnect: _disconnect,
              ),
              const SizedBox(height: 16),
              if (busyLabel != null) ...[
                Card(
                  child: ListTile(
                    leading: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    title: Text(busyLabel),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (s.user != null) ...[
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(s.lastBackupAt == null
                      ? l.noBackupFound
                      : l.lastBackupAt(
                          dateF.dateTime(s.lastBackupAt!))),
                  subtitle: s.lastBackupSizeBytes == null
                      ? null
                      : Text(_formatSize(s.lastBackupSizeBytes!)),
                ),
                FilledButton.icon(
                  onPressed: s.busy == BackupBusy.none ? _doBackup : null,
                  icon: const Icon(Icons.backup_outlined),
                  label: Text(l.backupNow),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      s.busy == BackupBusy.none ? _restorePressed : null,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l.restoreFromBackup),
                ),
                SwitchListTile(
                  title: Text(l.autoBackup),
                  subtitle: Text(l.autoBackupSubtitle),
                  value: s.autoBackup,
                  onChanged: (v) => ref
                      .read(backupNotifierProvider.notifier)
                      .setAutoBackup(v),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _ConflictChoice { keepDevice, restoreCloud, later }

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.busy,
    required this.onSignIn,
    required this.onSignOut,
    required this.onDisconnect,
  });

  final AuthUser? user;
  final bool busy;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final u = user;
    if (u == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.notSignedIn,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l.backupSignInHint,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : onSignIn,
                icon: const Icon(Icons.login),
                label: Text(l.signInWithGoogle),
              ),
            ],
          ),
        ),
      );
    }

    final initial = (u.displayName?.isNotEmpty == true
            ? u.displayName![0]
            : (u.email.isNotEmpty ? u.email[0] : '?'))
        .toUpperCase();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          // Falls back to the initial if the avatar can't load (offline).
          foregroundImage: u.photoUrl == null ? null : NetworkImage(u.photoUrl!),
          child: Text(initial),
        ),
        title: Text(u.displayName ?? u.email),
        subtitle: u.displayName == null ? null : Text(u.email),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'out' ? onSignOut() : onDisconnect(),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'out', child: Text(l.signOut)),
            PopupMenuItem(value: 'disconnect', child: Text(l.disconnectAccount)),
          ],
        ),
      ),
    );
  }
}
