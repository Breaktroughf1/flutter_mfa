import 'dart:typed_data';

/// The browser primitives the web vault needs (02_ARCHITECTURE §4.2).
///
/// Implemented with `package:web` by `BrowserWebStore`; kept as an interface
/// so the record format, AAD and error policy in `WebVault` run on the VM
/// (ADR-0008). Implementations never interpret, log or validate values and
/// throw only [WebStoreFailure].
abstract interface class WebStore {
  /// Whether the page is a secure context (HTTPS or localhost).
  bool get isSecureContext;

  /// Asks the browser to exempt this origin's storage from eviction and
  /// returns whether it agreed.
  Future<bool> requestPersistence();

  /// Encrypts [plaintext] with AES-256-GCM under the master key, creating a
  /// non-extractable master key first if there is none. Returns
  /// `ciphertext ‖ tag`.
  Future<Uint8List> seal(Uint8List nonce, Uint8List plaintext, Uint8List aad);

  /// Decrypts `ciphertext ‖ tag`, or returns `null` if there is no master key
  /// or authentication fails. Never creates a key.
  Future<Uint8List?> open(Uint8List nonce, Uint8List ciphertext, Uint8List aad);

  /// [length] bytes from the browser's CSPRNG.
  Uint8List randomBytes(int length);

  /// The record stored under [key], or `null`.
  Future<Uint8List?> get(String key);

  /// Stores [record] under [key], replacing any existing one.
  Future<void> put(String key, Uint8List record);

  /// Removes [key]; absent keys are ignored.
  Future<void> delete(String key);

  /// All record keys.
  Future<List<String>> keys();

  /// Removes every record and the master key.
  Future<void> clear();

  /// Writes [text] to the clipboard.
  Future<void> writeClipboard(String text);

  /// The clipboard text if this page may already read it without prompting
  /// the user, otherwise `null`.
  Future<String?> readClipboardIfPermitted();
}

/// A browser storage or crypto operation failed. Carries no detail: browser
/// error messages may echo inputs.
final class WebStoreFailure implements Exception {
  /// Creates a failure.
  const WebStoreFailure();

  @override
  String toString() => 'WebStoreFailure';
}
