import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';

import '../biometric_prompt.dart';
import '../mfa_platform.dart';
import '../vault_capabilities.dart';

/// Operations of [InMemoryMfaPlatform] that a test can make fail.
enum VaultOperation {
  /// [MfaPlatform.capabilities].
  capabilities,

  /// [MfaPlatform.write].
  write,

  /// [MfaPlatform.read].
  read,

  /// [MfaPlatform.delete].
  delete,

  /// [MfaPlatform.keys].
  keys,

  /// [MfaPlatform.wipe].
  wipe,
}

/// In-memory [MfaPlatform] for tests and demos. **Not secure**: values are
/// plain bytes in Dart memory.
///
/// Honours the vault contract: it rejects levels outside the configured
/// capabilities, simulates the biometric prompt for protected entries, keeps
/// defensive copies and fails with typed `VaultException`s on demand.
final class InMemoryMfaPlatform extends MfaPlatform {
  /// Creates an empty vault with [capabilities] (default: everything
  /// supported).
  InMemoryMfaPlatform({VaultCapabilities? capabilities})
    : currentCapabilities = capabilities ?? allCapabilities;

  /// A device that supports every protection level.
  static const allCapabilities = VaultCapabilities(
    hardwareBacked: true,
    strongBox: true,
    secureEnclave: true,
    biometricsEnrolled: true,
    secureContext: true,
    persistentStorage: true,
    screenCaptureProtection: true,
    supportedLevels: {
      ProtectionLevel.standard,
      ProtectionLevel.biometric,
      ProtectionLevel.hardwareBound,
    },
  );

  /// The capabilities reported; tests may replace them.
  VaultCapabilities currentCapabilities;

  /// Decides the outcome of a simulated biometric prompt. Return `false` to
  /// simulate the user cancelling. Default: approve.
  bool Function(BiometricPrompt? prompt) onBiometricPrompt = (_) => true;

  /// Prompts shown so far, oldest first.
  final List<BiometricPrompt?> prompts = [];

  /// Last text copied with [copySensitive] and its expiry.
  (String, Duration)? clipboard;

  /// Current screen-capture protection flag.
  bool screenCaptureProtected = false;

  final _entries = <String, (Uint8List, ProtectionLevel)>{};
  final _failures = <VaultOperation, (VaultException, String?)>{};

  /// Makes the next call of [operation] throw [error] (once). With [key],
  /// only the next call for that key fails (write, read, delete).
  void failNext(
    VaultOperation operation,
    VaultException error, {
    String? key,
  }) => _failures[operation] = (error, key);

  /// The protection level [key] was stored with, or `null`.
  ProtectionLevel? levelOf(String key) => _entries[key]?.$2;

  void _maybeFail(VaultOperation operation, [String? key]) {
    final failure = _failures[operation];
    if (failure == null || (failure.$2 != null && failure.$2 != key)) return;
    _failures.remove(operation);
    throw failure.$1;
  }

  @override
  Future<VaultCapabilities> capabilities() async {
    _maybeFail(VaultOperation.capabilities);
    return currentCapabilities;
  }

  @override
  Future<void> write(String key, Uint8List value, ProtectionLevel level) async {
    _maybeFail(VaultOperation.write, key);
    if (!currentCapabilities.supportedLevels.contains(level)) {
      throw const VaultHardwareUnavailable(
        HardwareUnavailableReason.unsupportedOnPlatform,
      );
    }
    _entries[key] = (Uint8List.fromList(value), level);
  }

  @override
  Future<Uint8List?> read(String key, {BiometricPrompt? prompt}) async {
    _maybeFail(VaultOperation.read, key);
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.$2 != ProtectionLevel.standard) {
      prompts.add(prompt);
      if (!onBiometricPrompt(prompt)) throw const VaultUserCancelled();
    }
    return Uint8List.fromList(entry.$1);
  }

  @override
  Future<void> delete(String key) async {
    _maybeFail(VaultOperation.delete, key);
    _entries.remove(key);
  }

  @override
  Future<List<String>> keys() async {
    _maybeFail(VaultOperation.keys);
    return _entries.keys.toList();
  }

  @override
  Future<void> wipe() async {
    _maybeFail(VaultOperation.wipe);
    _entries.clear();
  }

  @override
  Future<void> copySensitive(
    String text, {
    Duration expiry = const Duration(seconds: 30),
  }) async => clipboard = (text, expiry);

  @override
  Future<void> setScreenCaptureProtection(bool enabled) async =>
      screenCaptureProtected = enabled;
}
