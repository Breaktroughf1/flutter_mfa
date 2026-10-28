import 'package:flutter/services.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

import 'biometric_prompt.dart';
import 'messages.g.dart';
import 'mfa_platform.dart';
import 'vault_capabilities.dart';

/// [MfaPlatform] for Android and iOS over the Pigeon-generated channel.
///
/// This is the only place platform error codes become `VaultException`s
/// (02_ARCHITECTURE §6). Native error messages and details are discarded so
/// nothing from the platform layer can leak into app-visible errors.
final class MethodChannelMfaPlatform extends MfaPlatform {
  /// Creates the channel implementation; [api] is injectable for tests.
  MethodChannelMfaPlatform({MfaHostApi? api}) : _api = api ?? MfaHostApi();

  final MfaHostApi _api;

  @override
  Future<VaultCapabilities> capabilities() => _guard(() async {
    final m = await _api.capabilities();
    return VaultCapabilities(
      hardwareBacked: m.hardwareBacked,
      strongBox: m.strongBox,
      secureEnclave: m.secureEnclave,
      biometricsEnrolled: m.biometricsEnrolled,
      secureContext: true,
      persistentStorage: m.persistentStorage,
      screenCaptureProtection: m.screenCaptureProtection,
      supportedLevels: {
        for (final l in m.supportedLevels) ProtectionLevel.values[l.index],
      },
    );
  });

  @override
  Future<void> write(String key, Uint8List value, ProtectionLevel level) =>
      _guard(
        () =>
            _api.write(key, value, ProtectionLevelMessage.values[level.index]),
      );

  @override
  Future<Uint8List?> read(String key, {BiometricPrompt? prompt}) => _guard(
    () async {
      final bytes = await _api.read(
        key,
        prompt == null
            ? null
            : PromptMessage(
                title: prompt.title,
                subtitle: prompt.subtitle,
                cancelLabel: prompt.cancelLabel,
              ),
      );
      // The codec may hand back an unmodifiable view of the engine's
      // buffer; callers own the result and must be able to wipe it.
      return bytes == null ? null : Uint8List.fromList(bytes);
    },
  );

  @override
  Future<void> delete(String key) => _guard(() => _api.delete(key));

  @override
  Future<List<String>> keys() => _guard(_api.keys);

  @override
  Future<void> wipe() => _guard(_api.wipe);

  @override
  Future<void> copySensitive(
    String text, {
    Duration expiry = const Duration(seconds: 30),
  }) => _guard(() => _api.copySensitive(text, expiry.inMilliseconds));

  @override
  Future<void> setScreenCaptureProtection(bool enabled) =>
      _guard(() => _api.setScreenCaptureProtection(enabled));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw vaultExceptionFor(e.code);
    }
  }
}

/// Maps a platform error [code] to its typed exception; unknown codes become
/// [VaultUnknown] (fail closed, never a fallback).
VaultException vaultExceptionFor(String code) {
  final known = VaultErrorCode.values.where((c) => c.name == code).firstOrNull;
  return switch (known) {
    VaultErrorCode.notFound => const VaultNotFound(),
    VaultErrorCode.userCancelled => const VaultUserCancelled(),
    VaultErrorCode.keyInvalidated => const VaultKeyInvalidated(),
    VaultErrorCode.secureEnclaveUnavailable => const VaultHardwareUnavailable(
      HardwareUnavailableReason.secureEnclaveUnavailable,
    ),
    VaultErrorCode.strongBoxUnavailable => const VaultHardwareUnavailable(
      HardwareUnavailableReason.strongBoxUnavailable,
    ),
    VaultErrorCode.biometricsNotEnrolled => const VaultHardwareUnavailable(
      HardwareUnavailableReason.biometricsNotEnrolled,
    ),
    VaultErrorCode.biometricsUnavailable => const VaultHardwareUnavailable(
      HardwareUnavailableReason.biometricsUnavailable,
    ),
    VaultErrorCode.unsupportedOnPlatform => const VaultHardwareUnavailable(
      HardwareUnavailableReason.unsupportedOnPlatform,
    ),
    VaultErrorCode.hostActivityNotFragmentActivity => const VaultUnavailable(
      VaultUnavailableReason.hostActivityNotFragmentActivity,
    ),
    VaultErrorCode.storageUnavailable => const VaultUnavailable(
      VaultUnavailableReason.storageUnavailable,
    ),
    VaultErrorCode.deviceLocked => const VaultUnavailable(
      VaultUnavailableReason.deviceLocked,
    ),
    VaultErrorCode.corrupted => const VaultCorrupted(),
    null => VaultUnknown(code),
  };
}
