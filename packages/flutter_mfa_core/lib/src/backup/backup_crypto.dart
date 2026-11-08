import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'backup_crypto_none.dart'
    if (dart.library.js_interop) 'backup_crypto_web.dart'
    as platform;

/// The two primitives of backup format v1 (ADR-0007), behind one interface
/// so a platform can supply its own implementation (WebCrypto on the web,
/// ADR-0010). Every implementation must pass the frozen known-answer test.
abstract interface class BackupCrypto {
  /// PBKDF2-HMAC-SHA256 of [passphrase] with [salt], 32 bytes.
  Future<Uint8List> deriveKey(
    List<int> passphrase,
    Uint8List salt,
    int iterations,
  );

  /// AES-256-GCM: ciphertext followed by the 16-byte tag.
  Future<Uint8List> seal(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  );

  /// Opens [sealed] (ciphertext ‖ tag), or `null` if authentication fails.
  Future<Uint8List?> open(
    Uint8List key,
    Uint8List nonce,
    Uint8List sealed,
    Uint8List aad,
  );
}

/// The implementation backups use on this platform: WebCrypto in a browser
/// that offers it (ADR-0010, off the main thread), otherwise
/// [dartBackupCrypto]. Both give the same bytes; the frozen known-answer test
/// runs against each.
BackupCrypto get defaultBackupCrypto =>
    platform.platformBackupCrypto() ?? dartBackupCrypto;

/// The pure-Dart implementation (`cryptography`'s `DartPbkdf2` and
/// `DartAesGcm`): the reference, used on the VM and on Flutter's native
/// platforms.
const BackupCrypto dartBackupCrypto = _DartBackupCrypto();

const _tagLength = 16;

final class _DartBackupCrypto implements BackupCrypto {
  const _DartBackupCrypto();

  @override
  Future<Uint8List> deriveKey(
    List<int> passphrase,
    Uint8List salt,
    int iterations,
  ) async {
    final kdf = DartPbkdf2(
      macAlgorithm: DartHmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await kdf.deriveKey(
      secretKey: SecretKey(passphrase),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  @override
  Future<Uint8List> seal(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) async {
    final box = await DartAesGcm.with256bits().encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
  }

  @override
  Future<Uint8List?> open(
    Uint8List key,
    Uint8List nonce,
    Uint8List sealed,
    Uint8List aad,
  ) async {
    if (sealed.length < _tagLength) return null;
    final split = sealed.length - _tagLength;
    try {
      final plain = await DartAesGcm.with256bits().decrypt(
        SecretBox(
          sealed.sublist(0, split),
          nonce: nonce,
          mac: Mac(sealed.sublist(split)),
        ),
        secretKey: SecretKey(key),
        aad: aad,
      );
      final out = Uint8List.fromList(plain);
      if (plain is Uint8List) {
        plain.fillRange(0, plain.length, 0);
      }
      return out;
    } on SecretBoxAuthenticationError {
      return null;
    }
  }
}
