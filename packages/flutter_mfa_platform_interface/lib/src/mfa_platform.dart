import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'biometric_prompt.dart';
import 'method_channel_mfa_platform.dart';
import 'vault_capabilities.dart';

/// The single storage primitive every vault implements: a protected byte map
/// (02_ARCHITECTURE §4.1), plus the two OS hooks Dart cannot reach.
///
/// Contract for implementations:
/// * every failure is a typed `VaultException` (never a raw platform error);
/// * a protection level is never weakened: unsupported levels throw
///   `VaultHardwareUnavailable`;
/// * values are opaque bytes; implementations must not log, validate or
///   interpret them.
///
/// Implementations extend this class (it is `base`) so the
/// `PlatformInterface` token check cannot be bypassed by `implements`.
abstract base class MfaPlatform extends PlatformInterface {
  /// Constructs the platform; subclasses pass nothing.
  MfaPlatform() : super(token: _token);

  static final Object _token = Object();

  static MfaPlatform _instance = MethodChannelMfaPlatform();

  /// The implementation in use: the Pigeon channel on Android/iOS, replaced
  /// by the web vault on the web.
  static MfaPlatform get instance => _instance;

  /// Replaces the implementation (platform registration and tests).
  static set instance(MfaPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// What this device's vault can provide.
  Future<VaultCapabilities> capabilities();

  /// Stores [value] under [key] at protection [level], replacing any
  /// existing entry.
  Future<void> write(String key, Uint8List value, ProtectionLevel level);

  /// The bytes under [key], or `null` if absent. [prompt] is shown when the
  /// entry is biometric-protected. The caller owns the returned buffer: it is
  /// modifiable and should be overwritten once used.
  Future<Uint8List?> read(String key, {BiometricPrompt? prompt});

  /// Removes [key]; absent keys are ignored.
  Future<void> delete(String key);

  /// All keys in this plugin's namespace.
  Future<List<String>> keys();

  /// Removes every entry and key in this plugin's namespace.
  Future<void> wipe();

  /// Copies [text] to the clipboard marked sensitive (not synced, hidden from
  /// previews where the OS allows) and clears it after [expiry] (FR-FAC-05).
  Future<void> copySensitive(
    String text, {
    Duration expiry = const Duration(seconds: 30),
  });

  /// Blocks screenshots and screen recording of the app where supported
  /// (Android `FLAG_SECURE`); a no-op elsewhere, see
  /// [VaultCapabilities.screenCaptureProtection].
  Future<void> setScreenCaptureProtection(bool enabled);
}
