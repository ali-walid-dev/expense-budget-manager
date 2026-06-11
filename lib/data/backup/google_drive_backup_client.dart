import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'package:expense_budget_manager/data/backup/google_auth_service.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';
import 'package:expense_budget_manager/domain/backup/drive_backup_client.dart';

/// Google Drive implementation. Files live exclusively in the hidden
/// `appDataFolder` space (drive.appdata scope): private to the app, invisible
/// in the Drive UI, removed by Google when the user revokes the app's access.
class GoogleDriveBackupClient implements DriveBackupClient {
  GoogleDriveBackupClient(this._auth);
  final GoogleAuthService _auth;

  static const _space = 'appDataFolder';
  static const _maxAttempts = 3;

  @override
  Future<List<RemoteBackup>> list() => _run((api) async {
        final result = await api.files.list(
          spaces: _space,
          $fields: 'files(id,name,createdTime,size)',
          pageSize: 50,
        );
        final files = result.files ?? const <drive.File>[];
        final backups = files
            .where((f) => f.id != null && (f.name ?? '').startsWith('backup_'))
            .map((f) => RemoteBackup(
                  id: f.id!,
                  name: f.name ?? '',
                  createdAt: f.createdTime,
                  sizeBytes: int.tryParse(f.size ?? ''),
                ))
            .toList()
          ..sort((a, b) {
            final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
            final byTime = bt.compareTo(at);
            return byTime != 0 ? byTime : b.name.compareTo(a.name);
          });
        return backups;
      });

  @override
  Future<RemoteBackup> upload({required String name, required Uint8List bytes}) =>
      _run((api) async {
        final file = drive.File()
          ..name = name
          ..parents = [_space];
        final created = await api.files.create(
          file,
          uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
          $fields: 'id,name,createdTime,size',
        );
        return RemoteBackup(
          id: created.id!,
          name: created.name ?? name,
          createdAt: created.createdTime,
          sizeBytes: int.tryParse(created.size ?? '') ?? bytes.length,
        );
      });

  @override
  Future<Uint8List> download(String id) => _run((api) async {
        final media = await api.files.get(
          id,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
        final chunks = <int>[];
        await for (final chunk in media.stream) {
          chunks.addAll(chunk);
        }
        return Uint8List.fromList(chunks);
      });

  @override
  Future<void> delete(String id) => _run((api) => api.files.delete(id));

  /// Runs [op] with an authenticated DriveApi: exponential backoff on
  /// transient 429/5xx, one silent token-refresh retry on 401/403-auth, and
  /// mapping of every error onto a typed [BackupFailure]. Tokens and payloads
  /// are never logged.
  Future<T> _run<T>(Future<T> Function(drive.DriveApi api) op) async {
    var refreshedOnce = false;
    var attempt = 0;
    while (true) {
      attempt++;
      http.Client? client;
      try {
        client = await _auth.apiClient();
        if (client == null) throw const AuthFailure('not signed in');
        return await op(drive.DriveApi(client));
      } on BackupFailure {
        rethrow;
      } on drive.DetailedApiRequestError catch (e) {
        final status = e.status ?? 0;
        final message = e.message ?? '';
        if (status == 401 || (status == 403 && _isAuthError(message))) {
          if (!refreshedOnce && await _auth.refreshSession()) {
            refreshedOnce = true;
            continue; // retry with fresh token
          }
          throw AuthFailure('http $status');
        }
        if (status == 403 && _isQuotaError(message)) {
          throw QuotaFailure(message);
        }
        if ((status == 429 || status >= 500) && attempt < _maxAttempts) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        if (status == 429) throw QuotaFailure(message);
        if (status >= 500) throw NetworkFailure('http $status');
        throw UnknownBackupFailure(e);
      } on SocketException catch (e) {
        throw NetworkFailure(e.message);
      } on http.ClientException catch (e) {
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        throw NetworkFailure(e.message);
      } on TimeoutException {
        throw const NetworkFailure('timeout');
      } catch (e) {
        throw UnknownBackupFailure(e);
      } finally {
        client?.close();
      }
    }
  }

  static bool _isQuotaError(String message) {
    final m = message.toLowerCase();
    return m.contains('quota') || m.contains('storage') || m.contains('rate');
  }

  static bool _isAuthError(String message) {
    final m = message.toLowerCase();
    return m.contains('auth') ||
        m.contains('credential') ||
        m.contains('insufficient') ||
        m.contains('expired');
  }

  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 500 * (1 << attempt)); // 1s, 2s
}
