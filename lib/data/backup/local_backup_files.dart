import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Platform file plumbing for export/import, kept apart from
/// [LocalBackupRepository] so the encode/decode/merge logic stays unit
/// testable without a device.
class LocalBackupFiles {
  const LocalBackupFiles();

  /// Writes [bytes] to a temporary file and opens the system share sheet, so
  /// the user can save it to Files, Drive, or send it anywhere.
  Future<String> shareExport(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'qirshayn_backup_$stamp.json.gz'));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/gzip')],
      subject: 'Qirshayn backup',
    );
    return file.path;
  }

  /// Lets the user pick a backup file. Returns null when they cancel.
  ///
  /// The picker is deliberately unfiltered by extension: Android's document
  /// providers report `.json.gz` inconsistently, and a wrong filter shows the
  /// user an empty folder with no explanation. The file is validated on read
  /// instead, which is where a real answer comes from anyway.
  Future<Uint8List?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final data = picked.bytes;
    if (data != null) return data;

    final path = picked.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }
}
