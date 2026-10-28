import 'package:meta/meta.dart';

/// A one-time code ready to show the user.
///
/// The code is sensitive for its validity period (A2): [toString] is
/// redacted so it cannot end up in logs by accident.
@immutable
final class OtpCode {
  /// Creates a code value.
  const OtpCode({
    required this.value,
    required this.remaining,
    required this.progress,
    required this.step,
  });

  /// The digits, for example `"123456"`.
  final String value;

  /// TOTP: time left in the current step. HOTP: [Duration.zero].
  final Duration remaining;

  /// TOTP: elapsed fraction of the step in [0, 1). HOTP: 0.
  final double progress;

  /// TOTP: the time step. HOTP: the counter the code was generated for.
  final int step;

  /// The code split in two groups for readability (FR-UI-02):
  /// `123 456`, `1234 567`, `1234 5678`.
  String get grouped {
    final split = (value.length + 1) ~/ 2;
    return '${value.substring(0, split)} ${value.substring(split)}';
  }

  @override
  bool operator ==(Object other) =>
      other is OtpCode &&
      other.value == value &&
      other.remaining == remaining &&
      other.progress == progress &&
      other.step == step;

  @override
  int get hashCode => Object.hash(value, remaining, progress, step);

  @override
  String toString() =>
      'OtpCode(<redacted ${value.length} digits>, step: $step, remaining: ${remaining.inMilliseconds}ms)';
}
