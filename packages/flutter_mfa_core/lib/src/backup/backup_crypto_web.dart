import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'backup_crypto.dart';

/// WebCrypto (`crypto.subtle`) when the page offers it, which needs a secure
/// context; otherwise `null`, and the pure-Dart implementation is used. That
/// gives the same bytes and the same protection, only slower and on the main
/// thread (ADR-0010).
BackupCrypto? platformBackupCrypto() =>
    _crypto.has('subtle') && !_crypto.subtle.isUndefinedOrNull
    ? const _WebBackupCrypto()
    : null;

@JS('crypto')
external _Crypto get _crypto;

extension type _Crypto._(JSObject _) implements JSObject {
  external JSAny? get subtle;
}

@JS('crypto.subtle')
external _Subtle get _subtle;

extension type _Subtle._(JSObject _) implements JSObject {
  external JSPromise<JSObject> importKey(
    String format,
    JSUint8Array keyData,
    JSAny algorithm,
    bool extractable,
    JSArray<JSString> keyUsages,
  );

  external JSPromise<JSArrayBuffer> deriveBits(
    JSObject algorithm,
    JSObject baseKey,
    int length,
  );

  external JSPromise<JSArrayBuffer> encrypt(
    JSObject algorithm,
    JSObject key,
    JSUint8Array data,
  );

  external JSPromise<JSArrayBuffer> decrypt(
    JSObject algorithm,
    JSObject key,
    JSUint8Array data,
  );
}

extension type _Pbkdf2Params._(JSObject _) implements JSObject {
  external factory _Pbkdf2Params({
    String name,
    String hash,
    JSUint8Array salt,
    int iterations,
  });
}

extension type _AesGcmParams._(JSObject _) implements JSObject {
  external factory _AesGcmParams({
    String name,
    JSUint8Array iv,
    JSUint8Array additionalData,
    int tagLength,
  });
}

/// A copy of [bytes] in JavaScript memory, so it can be wiped after use
/// whatever the compiler (dart2js shares buffers, dart2wasm copies).
JSUint8Array _copyToJs(List<int> bytes) => Uint8List.fromList(bytes).toJS;

/// Wipes a JavaScript-side copy made by [_copyToJs].
void _wipe(JSUint8Array array) {
  final view = array.toDart;
  view.fillRange(0, view.length, 0);
}

/// Copies [buffer] into Dart memory and wipes the JavaScript side.
Uint8List _takeBytes(JSArrayBuffer buffer) {
  final view = JSUint8Array(buffer).toDart;
  final out = Uint8List.fromList(view);
  view.fillRange(0, view.length, 0);
  return out;
}

/// Whether [error], thrown by a rejected WebCrypto promise, is the
/// `OperationError` DOMException that AES-GCM uses for a failed tag check.
bool _isOperationError(Object error) {
  // A rejected promise surfaces as a JS object under dart2js and as a JS
  // value under dart2wasm; both pass this check (verified in Chrome).
  // ignore: invalid_runtime_check_with_js_interop_types
  if (error is! JSObject) return false;
  final name = error.getProperty<JSAny?>('name'.toJS);
  return name.isA<JSString>() && (name! as JSString).toDart == 'OperationError';
}

final class _WebBackupCrypto implements BackupCrypto {
  const _WebBackupCrypto();

  static const _tagBits = 128;

  Future<JSObject> _importAesKey(Uint8List key, String usage) async {
    final raw = _copyToJs(key);
    try {
      return await _subtle
          .importKey('raw', raw, 'AES-GCM'.toJS, false, [usage.toJS].toJS)
          .toDart;
    } finally {
      _wipe(raw);
    }
  }

  @override
  Future<Uint8List> deriveKey(
    List<int> passphrase,
    Uint8List salt,
    int iterations,
  ) async {
    final raw = _copyToJs(passphrase);
    final JSObject base;
    try {
      base = await _subtle
          .importKey('raw', raw, 'PBKDF2'.toJS, false, ['deriveBits'.toJS].toJS)
          .toDart;
    } finally {
      _wipe(raw);
    }
    final bits = await _subtle
        .deriveBits(
          _Pbkdf2Params(
            name: 'PBKDF2',
            hash: 'SHA-256',
            salt: Uint8List.fromList(salt).toJS,
            iterations: iterations,
          ),
          base,
          256,
        )
        .toDart;
    return _takeBytes(bits);
  }

  @override
  Future<Uint8List> seal(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) async {
    final cryptoKey = await _importAesKey(key, 'encrypt');
    final data = _copyToJs(plaintext);
    try {
      final sealed = await _subtle
          .encrypt(_params(nonce, aad), cryptoKey, data)
          .toDart;
      return _takeBytes(sealed);
    } finally {
      _wipe(data);
    }
  }

  @override
  Future<Uint8List?> open(
    Uint8List key,
    Uint8List nonce,
    Uint8List sealed,
    Uint8List aad,
  ) async {
    if (sealed.length < _tagBits ~/ 8) return null;
    final cryptoKey = await _importAesKey(key, 'decrypt');
    final JSArrayBuffer plain;
    try {
      plain = await _subtle
          .decrypt(_params(nonce, aad), cryptoKey, _copyToJs(sealed))
          .toDart;
      // A failed authentication rejects with an OperationError. Anything
      // else is not a wrong passphrase and is passed on.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (_isOperationError(e)) return null;
      rethrow;
    }
    return _takeBytes(plain);
  }

  _AesGcmParams _params(Uint8List nonce, Uint8List aad) => _AesGcmParams(
    name: 'AES-GCM',
    iv: Uint8List.fromList(nonce).toJS,
    additionalData: Uint8List.fromList(aad).toJS,
    tagLength: _tagBits,
  );
}
