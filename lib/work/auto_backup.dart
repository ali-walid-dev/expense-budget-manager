import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:expense_budget_manager/data/backup/backup_preferences.dart';
import 'package:expense_budget_manager/data/backup/google_auth_service.dart';
import 'package:expense_budget_manager/data/local/db/app_database.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';
import 'package:expense_budget_manager/domain/backup/backup_repository.dart';

/// Debounced, silent auto-backup:
///  - any table change marks the state dirty and arms a trailing 3-minute
///    timer (so bursts of edits collapse into one upload);
///  - backups run at most once per 10 minutes;
///  - app going to background flushes a pending dirty state immediately;
///  - failures are swallowed (never block or toast the UI) and recorded as
///    `pendingBackup` so the next launch/foreground retries;
///  - also performs the silent sign-in on app start so the session survives
///    restarts.
class AutoBackupController with WidgetsBindingObserver {
  AutoBackupController({
    required this.db,
    required this.auth,
    required this.repo,
    required this.prefs,
  });

  final AppDatabase db;
  final GoogleAuthService auth;
  final BackupRepository repo;
  final BackupPreferences prefs;

  static const _debounce = Duration(minutes: 3);
  static const _minInterval = Duration(minutes: 10);

  Timer? _timer;
  StreamSubscription<Object?>? _sub;
  bool _dirty = false;
  bool _started = false;
  bool _running = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    // Lightweight re-auth so the user stays signed in across sessions.
    await auth.signInSilently();

    _sub = db.tableUpdates().listen((_) => _onDataChanged());

    // Retry a backup that failed offline last session.
    if (prefs.pendingBackup && _eligible) {
      _schedule(const Duration(seconds: 30));
    }
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
  }

  bool get _eligible => prefs.autoBackupEnabled && auth.currentUser != null;

  void _onDataChanged() {
    if (!_eligible) return;
    _dirty = true;
    _schedule(_debounce);
  }

  void _schedule(Duration delay) {
    if (_timer != null) return; // trailing edge — keep the earliest deadline
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_run());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        (_dirty || prefs.pendingBackup) &&
        _eligible) {
      _timer?.cancel();
      _timer = null;
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    if (_running || !_eligible) return;

    // Respect the once-per-10-minutes cap: re-arm for the remaining window.
    final last = prefs.lastBackupAt;
    if (last != null) {
      final since = DateTime.now().difference(last);
      if (since < _minInterval) {
        _schedule(_minInterval - since);
        return;
      }
    }

    _running = true;
    _dirty = false;
    try {
      await repo.backupNow();
      await prefs.setPendingBackup(false);
    } on BackupFailure catch (e) {
      // Silent by design: queue a retry, surface nothing.
      await prefs.setPendingBackup(true);
      if (kDebugMode) debugPrint('auto-backup failed: $e');
    } catch (e) {
      await prefs.setPendingBackup(true);
      if (kDebugMode) debugPrint('auto-backup failed: $e');
    } finally {
      _running = false;
    }
  }
}
