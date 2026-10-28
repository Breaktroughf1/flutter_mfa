import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';

import 'web_store.dart';

/// The protected byte map on the web (02_ARCHITECTURE §4.2, FR-VLT-04).
///
/// Each entry is one IndexedDB record
/// `version(1) ‖ protection(1) ‖ nonce(12) ‖ ciphertext ‖ tag(16)`, encrypted
/// with AES-256-GCM under a non-extractable `CryptoKey`. The AAD binds the
/// header and the key name, so a record cannot be moved to another key or
/// relabelled with a different protection level.
///
/// Protects against key export by page script and against values ever
/// appearing in clear in IndexedDB. Does **not** protect against script
/// running in the page origin (XSS), which can still ask the browser to
/// decrypt (S12), nor against an attacker who can read the browser profile
/// on disk, where the browser keeps the key material.
/// Only `ProtectionLevel.standard` exists on the web; other levels are
/// refused, never downgraded. Outside a secure context every storage
/// operation throws `VaultUnavailable(insecureContext)`.
final class WebVault extends MfaPlatform {
  /// Creates a vault over [store].
  WebVault(this._store);

  static const _formatVersion = 1;
  static const _headerSize = 2;
  static const _nonceSize = 12;
  static const _tagSize = 16;
  static final _aadPrefix = utf8.encode('flutter_mfa.v1:');

  final WebStore _store;
  Future<bool>? _persisted;

  Future<bool> _persist() => _persisted ??= _store
      .requestPersistence()
      .catchError((Object _) => false);

  @override
  Future<VaultCapabilities> capabilities() async {
    final secure = _store.isSecureContext;
    return VaultCapabilities(
      hardwareBacked: false,
      strongBox: false,
      secureEnclave: false,
      biometricsEnrolled: false,
      secureContext: secure,
      persistentStorage: secure && await _persist(),
      screenCaptureProtection: false,
      supportedLevels: secure ? const {ProtectionLevel.standard} : const {},
    );
  }

  @override
  Future<void> write(String key, Uint8List value, ProtectionLevel level) =>
      _guard(() async {
        if (level != ProtectionLevel.standard) {
          throw const VaultHardwareUnavailable(
            HardwareUnavailableReason.unsupportedOnPlatform,
          );
        }
        await _persist();
        final header = Uint8List.fromList([_formatVersion, level.index]);
        final nonce = _store.randomBytes(_nonceSize);
        final sealed = await _store.seal(nonce, value, _aad(header, key));
        await _store.put(
          key,
          Uint8List.fromList([...header, ...nonce, ...sealed]),
        );
      });

  @override
  Future<Uint8List?> read(String key, {BiometricPrompt? prompt}) =>
      _guard(() async {
        final record = await _store.get(key);
        if (record == null) return null;
        if (record.length < _headerSize + _nonceSize + _tagSize ||
            record[0] != _formatVersion ||
            record[1] != ProtectionLevel.standard.index) {
          throw const VaultCorrupted();
        }
        final opened = await _store.open(
          Uint8List.sublistView(record, _headerSize, _headerSize + _nonceSize),
          Uint8List.sublistView(record, _headerSize + _nonceSize),
          _aad(Uint8List.sublistView(record, 0, _headerSize), key),
        );
        if (opened == null) throw const VaultCorrupted();
        return opened;
      });

  @override
  Future<void> delete(String key) => _guard(() => _store.delete(key));

  @override
  Future<List<String>> keys() =>
      _guard(() async => (await _store.keys())..sort());

  @override
  Future<void> wipe() => _guard(_store.clear);

  /// Copies [text] and clears it after [expiry] if it is verifiably still
  /// ours. Browsers offer no sensitive-clip flag; the clip is cleared only
  /// when the page may already read the clipboard without prompting, so a
  /// later copy by the user is never wiped and no permission prompt appears.
  @override
  Future<void> copySensitive(
    String text, {
    Duration expiry = const Duration(seconds: 30),
  }) async {
    try {
      await _store.writeClipboard(text);
    } on WebStoreFailure {
      throw const VaultUnavailable(VaultUnavailableReason.storageUnavailable);
    }
    unawaited(
      Future<void>.delayed(expiry, () async {
        try {
          if (await _store.readClipboardIfPermitted() == text) {
            await _store.writeClipboard('');
          }
        } on WebStoreFailure {
          // Best effort: the page may have lost focus.
        }
      }),
    );
  }

  /// Browsers cannot block screenshots; reported via [capabilities].
  @override
  Future<void> setScreenCaptureProtection(bool enabled) async {}

  Future<T> _guard<T>(Future<T> Function() body) async {
    if (!_store.isSecureContext) {
      throw const VaultUnavailable(VaultUnavailableReason.insecureContext);
    }
    try {
      return await body();
    } on WebStoreFailure {
      throw const VaultUnavailable(VaultUnavailableReason.storageUnavailable);
    }
  }

  static Uint8List _aad(Uint8List header, String key) =>
      Uint8List.fromList([..._aadPrefix, ...header, ...utf8.encode(key)]);
}
