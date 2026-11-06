import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../errors/mfa_exception.dart';
import 'backup_crypto.dart';
import 'backup_entry.dart';
import 'backup_format.dart';
import 'passphrase_check.dart';
import 'passphrase_policy.dart';

/// Encrypts and decrypts backups in format v1: PBKDF2-HMAC-SHA256 and
/// AES-256-GCM, with the header authenticated (FR-BAK-01, ADR-0007).
///
/// There is no plaintext export: a backup holds every account's secret, so
/// it is always encrypted under a passphrase that meets [PassphrasePolicy].
/// The key derivation is deliberately slow (600 000 iterations take a few
/// seconds): in a Flutter app run it off the UI isolate. It protects against
/// guessing weak passphrases only up to the policy; it does not protect a
/// backup whose passphrase is known, and memory cannot be reliably wiped of
/// the Base32 secrets that pass through the JSON plaintext.
final class BackupCodec {
  /// A codec writing [iterations] PBKDF2 iterations (at least
  /// `210 000`, the lowest any reader accepts).
  const BackupCodec({this.iterations = backupDefaultIterations});

  /// PBKDF2 iterations used by [encrypt].
  final int iterations;

  static const _armorBegin = '-----BEGIN FLUTTER MFA BACKUP-----';
  static const _armorEnd = '-----END FLUTTER MFA BACKUP-----';

  /// Encrypts [entries] under [passphrase] with a fresh random salt and
  /// nonce (`Random.secure()` unless [random] is supplied, which only tests
  /// should do).
  ///
  /// Throws [BackupWeakPassphrase] when the passphrase fails the policy, and
  /// `OtpConfigException` when [iterations] is outside the accepted range.
  Future<Uint8List> encrypt(
    List<BackupEntry> entries,
    String passphrase, {
    Random? random,
  }) async {
    if (iterations < backupMinIterations || iterations > backupMaxIterations) {
      throw const OtpConfigException(
        field: 'iterations',
        reason: 'must be 210 000 to 10 000 000',
      );
    }
    final check = PassphrasePolicy.check(passphrase);
    if (check != PassphraseCheck.ok) throw BackupWeakPassphrase(check);
    final rng = random ?? Random.secure();
    Uint8List bytes(int n) =>
        Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
    return sealBackup(
      defaultBackupCrypto,
      entries: entries,
      passphrase: passphrase,
      salt: bytes(16),
      nonce: bytes(12),
      iterations: iterations,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Decrypts a backup made by [encrypt] on any platform.
  ///
  /// Throws [BackupDecryptFailed] for a wrong passphrase or any modified,
  /// truncated or foreign data (deliberately indistinguishable), and
  /// [BackupUnsupportedVersion] for a format version, KDF or iteration count
  /// this reader does not accept. The passphrase policy is not applied, so
  /// any backup can be restored.
  Future<List<BackupEntry>> decrypt(Uint8List data, String passphrase) =>
      openBackup(defaultBackupCrypto, data, passphrase);

  /// [data] as ASCII armour: base64 in 64-column lines between BEGIN and END
  /// markers, for copying and pasting.
  String armor(Uint8List data) {
    final encoded = base64.encode(data);
    final lines = [
      for (var i = 0; i < encoded.length; i += 64)
        encoded.substring(i, min(i + 64, encoded.length)),
    ];
    return '$_armorBegin\n${lines.join('\n')}\n$_armorEnd\n';
  }

  /// The bytes inside [armor] output. Whitespace and line endings are
  /// ignored. Throws [BackupDecryptFailed] for text that is not an armoured
  /// backup.
  Uint8List dearmor(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(_armorBegin) || !trimmed.endsWith(_armorEnd)) {
      throw const BackupDecryptFailed();
    }
    final body = trimmed
        .substring(_armorBegin.length, trimmed.length - _armorEnd.length)
        .replaceAll(RegExp(r'\s'), '');
    try {
      return base64.decode(body);
    } on FormatException {
      throw const BackupDecryptFailed();
    }
  }
}
