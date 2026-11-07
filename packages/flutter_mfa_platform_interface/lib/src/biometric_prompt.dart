import 'package:meta/meta.dart';

/// Text for the system biometric prompt shown when reading an entry stored
/// with `ProtectionLevel.biometric` or `hardwareBound`.
///
/// The prompt is drawn by the OS; this only supplies its strings. It is not
/// an authentication API: the entry is decrypted only through the
/// biometric-bound key operation (FR-VLT-06), never via a boolean result.
@immutable
final class BiometricPrompt {
  /// Creates prompt text.
  const BiometricPrompt({
    required this.title,
    this.subtitle,
    this.cancelLabel = 'Cancel',
  });

  /// Main line, for example "Unlock code".
  final String title;

  /// Optional second line.
  final String? subtitle;

  /// Label of the cancel button (Android). iOS uses the system label.
  final String cancelLabel;

  @override
  bool operator ==(Object other) =>
      other is BiometricPrompt &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.cancelLabel == cancelLabel;

  @override
  int get hashCode => Object.hash(title, subtitle, cancelLabel);

  @override
  String toString() => 'BiometricPrompt($title)';
}
