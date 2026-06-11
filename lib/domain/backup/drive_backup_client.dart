import 'dart:typed_data';

/// A backup file as it exists in the cloud store.
class RemoteBackup {
  const RemoteBackup({
    required this.id,
    required this.name,
    this.createdAt,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final int? sizeBytes;
}

/// Storage seam for backup blobs. The Google Drive implementation stores them
/// in the hidden appDataFolder; an iCloud/WebDAV implementation could replace
/// it without touching [BackupRepository] or the UI.
///
/// All methods throw [BackupFailure] subtypes on error.
abstract class DriveBackupClient {
  /// Backups, newest first.
  Future<List<RemoteBackup>> list();

  Future<RemoteBackup> upload({required String name, required Uint8List bytes});

  Future<Uint8List> download(String id);

  Future<void> delete(String id);
}
