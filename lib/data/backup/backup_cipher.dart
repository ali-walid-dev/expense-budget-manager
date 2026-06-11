import 'dart:typed_data';

/// Optional at-rest encryption applied to the compressed backup *before*
/// upload. Kept behind an interface per spec so AES-GCM (key from a user
/// passphrase or secure storage) can be enabled later without touching the
/// repository, Drive client, or UI.
abstract class BackupCipher {
  /// Identifier baked into the uploaded file name suffix convention; lets a
  /// future implementation detect how a blob was protected.
  String get id;

  Future<Uint8List> encrypt(Uint8List plain);
  Future<Uint8List> decrypt(Uint8List data);
}

/// Default: no encryption (transport is TLS; storage is the account-private
/// appDataFolder).
class NoopBackupCipher implements BackupCipher {
  const NoopBackupCipher();

  @override
  String get id => 'none';

  @override
  Future<Uint8List> encrypt(Uint8List plain) async => plain;

  @override
  Future<Uint8List> decrypt(Uint8List data) async => data;
}
