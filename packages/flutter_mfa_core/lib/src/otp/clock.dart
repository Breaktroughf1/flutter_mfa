/// Source of the current time, injectable so tests and servers control it
/// (FR-OTP-02 AC3).
abstract interface class Clock {
  /// The current instant.
  DateTime now();
}

/// [Clock] backed by the system clock.
///
/// TOTP correctness depends on the device clock; this class does not detect
/// or correct clock skew (the verifier's drift window absorbs small skew).
final class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
