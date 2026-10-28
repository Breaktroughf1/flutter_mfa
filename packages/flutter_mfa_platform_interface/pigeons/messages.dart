// Pigeon schema: the single source of truth for the mobile wire format and
// vault error codes (02_ARCHITECTURE §4.1, §6). Regenerate with
// `melos run pigeon`; never edit the generated files by hand.
//
// Native code is a thin byte vault: no OTP logic, JSON or validation.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_mfa_platform_interface',
    kotlinOut:
        '../flutter_mfa/android/src/main/kotlin/com/breaktroughf1/flutter_mfa/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.breaktroughf1.flutter_mfa'),
    swiftOut:
        '../flutter_mfa/ios/flutter_mfa/Sources/flutter_mfa/Messages.g.swift',
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
/// Protection level requested for an entry.
enum ProtectionLevelMessage { standard, biometric, hardwareBound }

/// Error codes native code returns as the `code` of a platform error. Mapped
/// to `VaultException` exactly once, in `MethodChannelMfaPlatform`.
enum VaultErrorCode {
  notFound,
  userCancelled,
  keyInvalidated,
  secureEnclaveUnavailable,
  strongBoxUnavailable,
  biometricsNotEnrolled,
  biometricsUnavailable,
  unsupportedOnPlatform,
  hostActivityNotFragmentActivity,
  storageUnavailable,
  deviceLocked,
  corrupted,
}

/// What the device's vault can provide.
class CapabilitiesMessage {
  CapabilitiesMessage({
    required this.hardwareBacked,
    required this.strongBox,
    required this.secureEnclave,
    required this.biometricsEnrolled,
    required this.persistentStorage,
    required this.screenCaptureProtection,
    required this.supportedLevels,
  });

  bool hardwareBacked;
  bool strongBox;
  bool secureEnclave;
  bool biometricsEnrolled;
  bool persistentStorage;
  bool screenCaptureProtection;
  List<ProtectionLevelMessage> supportedLevels;
}

/// Text of the system biometric prompt.
class PromptMessage {
  PromptMessage({
    required this.title,
    required this.cancelLabel,
    this.subtitle,
  });

  String title;
  String? subtitle;
  String cancelLabel;
}

/// The protected byte map implemented by Android and iOS.
@HostApi()
abstract class MfaHostApi {
  CapabilitiesMessage capabilities();

  @async
  void write(String key, Uint8List value, ProtectionLevelMessage level);

  /// Returns null when the key does not exist.
  @async
  Uint8List? read(String key, PromptMessage? prompt);

  void delete(String key);

  List<String> keys();

  void wipe();

  void copySensitive(String text, int expiryMillis);

  void setScreenCaptureProtection(bool enabled);
}
