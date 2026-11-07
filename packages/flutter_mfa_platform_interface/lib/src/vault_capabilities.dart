import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:meta/meta.dart';

/// What the device's secure vault can provide (FR-VLT-05 AC1).
///
/// Apps use it to offer only achievable protection levels. Requesting a
/// level outside [supportedLevels] throws `VaultHardwareUnavailable`; the
/// vault never silently falls back to weaker protection.
@immutable
final class VaultCapabilities {
  /// Creates a capability report.
  const VaultCapabilities({
    required this.hardwareBacked,
    required this.strongBox,
    required this.secureEnclave,
    required this.biometricsEnrolled,
    required this.secureContext,
    required this.persistentStorage,
    required this.screenCaptureProtection,
    required this.supportedLevels,
  });

  /// Keys live in a TEE, StrongBox, Secure Enclave or Keychain rather than in
  /// app memory or files.
  final bool hardwareBacked;

  /// Android StrongBox (dedicated secure element) is available.
  final bool strongBox;

  /// iOS Secure Enclave is available.
  final bool secureEnclave;

  /// At least one strong biometric is enrolled.
  final bool biometricsEnrolled;

  /// Web only: the page is a secure context (HTTPS or localhost). Always
  /// `true` on mobile.
  final bool secureContext;

  /// Stored data survives storage pressure. Always `true` on mobile; on the
  /// web it reflects `navigator.storage.persist()`. When `false`, prompt the
  /// user to make an encrypted backup.
  final bool persistentStorage;

  /// `setScreenCaptureProtection` has an effect here (Android only, FR-FAC-06).
  final bool screenCaptureProtection;

  /// Protection levels that `write` accepts on this device.
  final Set<ProtectionLevel> supportedLevels;

  @override
  bool operator ==(Object other) =>
      other is VaultCapabilities &&
      other.hardwareBacked == hardwareBacked &&
      other.strongBox == strongBox &&
      other.secureEnclave == secureEnclave &&
      other.biometricsEnrolled == biometricsEnrolled &&
      other.secureContext == secureContext &&
      other.persistentStorage == persistentStorage &&
      other.screenCaptureProtection == screenCaptureProtection &&
      other.supportedLevels.length == supportedLevels.length &&
      other.supportedLevels.containsAll(supportedLevels);

  @override
  int get hashCode => Object.hash(
    hardwareBacked,
    strongBox,
    secureEnclave,
    biometricsEnrolled,
    secureContext,
    persistentStorage,
    screenCaptureProtection,
    Object.hashAllUnordered(supportedLevels),
  );

  @override
  String toString() =>
      'VaultCapabilities(hardwareBacked: $hardwareBacked, strongBox: $strongBox, '
      'secureEnclave: $secureEnclave, biometricsEnrolled: $biometricsEnrolled, '
      'secureContext: $secureContext, persistentStorage: $persistentStorage, '
      'screenCaptureProtection: $screenCaptureProtection, '
      'levels: ${supportedLevels.map((l) => l.name).join('/')})';
}
