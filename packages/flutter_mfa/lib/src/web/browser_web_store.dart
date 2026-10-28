import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_store.dart';

/// [WebStore] over IndexedDB and WebCrypto (02_ARCHITECTURE §4.2).
///
/// Database `flutter_mfa_v1` holds the master `CryptoKey` (AES-256-GCM,
/// generated with `extractable: false`; structured clone keeps it
/// non-extractable) in store `keys` and the records in store `records`. The
/// key is read from IndexedDB on every use rather than cached, so a wipe in
/// another tab is never undone by a stale key; concurrent first writes, in
/// this tab or another, converge on the one key that `add` stored first.
/// A thin layer: no record format, validation or logging lives here.
final class BrowserWebStore implements WebStore {
  static const _database = 'flutter_mfa_v1';
  static const _keysStore = 'keys';
  static const _recordsStore = 'records';
  static const _masterKey = 'master';

  Future<web.IDBDatabase>? _db;

  @override
  bool get isSecureContext => web.window.isSecureContext;

  @override
  Future<bool> requestPersistence() => _wrap(
    () async => (await web.window.navigator.storage.persist().toDart).toDart,
  );

  @override
  Future<Uint8List> seal(Uint8List nonce, Uint8List plaintext, Uint8List aad) =>
      _wrap(() async {
        final key = await _loadKey() ?? await _createKey();
        final result = await web.window.crypto.subtle
            .encrypt(_gcm(nonce, aad), key, plaintext.toJS)
            .toDart;
        return (result! as JSArrayBuffer).toDart.asUint8List();
      });

  @override
  Future<Uint8List?> open(
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) => _wrap(() async {
    final key = await _loadKey();
    if (key == null) return null;
    try {
      final result = await web.window.crypto.subtle
          .decrypt(_gcm(nonce, aad), key, ciphertext.toJS)
          .toDart;
      return (result! as JSArrayBuffer).toDart.asUint8List();
    } on Object {
      // OperationError: authentication failed (tampered or foreign record).
      return null;
    }
  });

  @override
  Uint8List randomBytes(int length) {
    final bytes = JSUint8Array.withLength(length);
    web.window.crypto.getRandomValues(bytes);
    return bytes.toDart;
  }

  @override
  Future<Uint8List?> get(String key) => _wrap(() async {
    final value = await _request(
      _recordsStore,
      'readonly',
      (store) => store.get(key.toJS),
    );
    if (value == null) return null;
    // A value of another type cannot be a record; WebVault rejects it.
    return value.isA<JSUint8Array>()
        ? (value as JSUint8Array).toDart
        : Uint8List(0);
  });

  @override
  Future<void> put(String key, Uint8List record) => _wrap(
    () => _request(
      _recordsStore,
      'readwrite',
      (store) => store.put(record.toJS, key.toJS),
    ),
  );

  @override
  Future<void> delete(String key) => _wrap(
    () => _request(
      _recordsStore,
      'readwrite',
      (store) => store.delete(key.toJS),
    ),
  );

  @override
  Future<List<String>> keys() => _wrap(() async {
    final result = await _request(
      _recordsStore,
      'readonly',
      (store) => store.getAllKeys(),
    );
    return [
      for (final k in (result! as JSArray<JSAny?>).toDart)
        if (k != null && k.isA<JSString>()) (k as JSString).toDart,
    ];
  });

  @override
  Future<void> clear() => _wrap(() async {
    final db = await _open();
    final tx = db.transaction(
      [_recordsStore.toJS, _keysStore.toJS].toJS,
      'readwrite',
    );
    tx.objectStore(_recordsStore).clear();
    tx.objectStore(_keysStore).clear();
    await _completion(tx);
  });

  @override
  Future<void> writeClipboard(String text) => _wrap(
    () => web.window.navigator.clipboard.writeText(text).toDart,
  );

  @override
  Future<String?> readClipboardIfPermitted() async {
    try {
      final status = await web.window.navigator.permissions
          .query(_PermissionDescriptor(name: 'clipboard-read'))
          .toDart;
      if (status.state != 'granted') return null;
      return (await web.window.navigator.clipboard.readText().toDart).toDart;
    } on Object {
      // Not supported (Firefox, Safari) or not focused: cannot verify.
      return null;
    }
  }

  static JSObject _gcm(Uint8List nonce, Uint8List aad) => _AesGcmParams(
    name: 'AES-GCM',
    iv: nonce.toJS,
    additionalData: aad.toJS,
    tagLength: 128,
  );

  Future<web.CryptoKey?> _loadKey() async {
    final value = await _request(
      _keysStore,
      'readonly',
      (store) => store.get(_masterKey.toJS),
    );
    return value == null ? null : value as web.CryptoKey;
  }

  Future<web.CryptoKey> _createKey() async {
    final generated =
        await web.window.crypto.subtle
                .generateKey(
                  _AesKeyGenParams(name: 'AES-GCM', length: 256),
                  false,
                  ['encrypt'.toJS, 'decrypt'.toJS].toJS,
                )
                .toDart
            as web.CryptoKey;
    try {
      // `add` fails if another writer stored a key first; theirs wins.
      await _request(
        _keysStore,
        'readwrite',
        (store) => store.add(generated, _masterKey.toJS),
      );
    } on WebStoreFailure {
      // Fall through and use the key that is stored.
    }
    final stored = await _loadKey();
    if (stored == null) throw const WebStoreFailure();
    return stored;
  }

  Future<web.IDBDatabase> _open() async {
    final pending = _db ??= _openDatabase();
    try {
      return await pending;
    } on Object {
      // Let the next call retry (for example after storage was unblocked).
      if (identical(_db, pending)) _db = null;
      rethrow;
    }
  }

  Future<web.IDBDatabase> _openDatabase() {
    final factory = web.window.indexedDB;
    final request = factory.open(_database, 1);
    final completer = Completer<web.IDBDatabase>();
    request
      ..onupgradeneeded = ((web.Event _) {
        final db = request.result! as web.IDBDatabase;
        db
          ..createObjectStore(_keysStore)
          ..createObjectStore(_recordsStore);
      }).toJS
      ..onsuccess = ((web.Event _) {
        completer.complete(request.result! as web.IDBDatabase);
      }).toJS
      ..onerror = ((web.Event _) {
        completer.completeError(const WebStoreFailure());
      }).toJS;
    return completer.future;
  }

  /// Runs [operation] in its own transaction on [storeName] and returns the
  /// request's result once the transaction has committed.
  Future<JSAny?> _request(
    String storeName,
    String mode,
    web.IDBRequest Function(web.IDBObjectStore store) operation,
  ) async {
    final db = await _open();
    final tx = db.transaction(storeName.toJS, mode);
    final request = operation(tx.objectStore(storeName));
    await _completion(tx);
    return request.result;
  }

  static Future<void> _completion(web.IDBTransaction tx) {
    final completer = Completer<void>();
    tx
      ..oncomplete = ((web.Event _) => completer.complete()).toJS
      ..onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(const WebStoreFailure());
        }
      }).toJS
      ..onabort = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(const WebStoreFailure());
        }
      }).toJS;
    return completer.future;
  }

  /// Runs [body], turning any browser error into a detail-free
  /// [WebStoreFailure] (browser messages may echo inputs).
  static Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on WebStoreFailure {
      rethrow;
    } on Object {
      throw const WebStoreFailure();
    }
  }
}

extension type _AesGcmParams._(JSObject _) implements JSObject {
  external factory _AesGcmParams({
    String name,
    JSUint8Array iv,
    JSUint8Array additionalData,
    int tagLength,
  });
}

extension type _AesKeyGenParams._(JSObject _) implements JSObject {
  external factory _AesKeyGenParams({String name, int length});
}

extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({String name});
}
