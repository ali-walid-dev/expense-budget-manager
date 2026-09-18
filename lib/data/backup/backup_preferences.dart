import 'package:shared_preferences/shared_preferences.dart';

/// Device-local backup metadata. Intentionally NOT part of the backup payload
/// (it describes this device's relationship to the cloud, not user data).
class BackupPreferences {
  BackupPreferences(this._prefs);
  final SharedPreferences _prefs;

  static const _kAuto = 'bk_auto_enabled';
  static const _kLastAt = 'bk_last_at_millis';
  static const _kLastSize = 'bk_last_size_bytes';
  static const _kBoundAccount = 'bk_bound_account_id';
  static const _kPending = 'bk_pending_retry';

  /// Auto-backup toggle (default off — backup is strictly opt-in).
  bool get autoBackupEnabled => _prefs.getBool(_kAuto) ?? false;
  Future<void> setAutoBackupEnabled(bool v) => _prefs.setBool(_kAuto, v);

  DateTime? get lastBackupAt {
    final ms = _prefs.getInt(_kLastAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  int? get lastBackupSizeBytes => _prefs.getInt(_kLastSize);

  Future<void> setLastBackup(DateTime at, int sizeBytes) async {
    await _prefs.setInt(_kLastAt, at.millisecondsSinceEpoch);
    await _prefs.setInt(_kLastSize, sizeBytes);
  }

  /// The Google account id this device's data belongs to — set on every
  /// successful backup or restore. A sign-in with a different id while local
  /// data exists triggers the explicit conflict flow.
  String? get boundAccountId => _prefs.getString(_kBoundAccount);
  Future<void> bindAccount(String id) => _prefs.setString(_kBoundAccount, id);

  /// Set when an auto-backup failed (e.g. offline) so it can be retried on
  /// the next launch/foreground without ever blocking the UI.
  bool get pendingBackup => _prefs.getBool(_kPending) ?? false;
  Future<void> setPendingBackup(bool v) => _prefs.setBool(_kPending, v);
}
