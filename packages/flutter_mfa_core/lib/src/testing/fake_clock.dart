import '../otp/clock.dart';

/// A [Clock] whose time only changes when a test says so. Tests only.
final class FakeClock implements Clock {
  /// Creates a clock frozen at [time].
  FakeClock(this.time);

  /// The current fake time.
  DateTime time;

  @override
  DateTime now() => time;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => time = time.add(duration);
}
