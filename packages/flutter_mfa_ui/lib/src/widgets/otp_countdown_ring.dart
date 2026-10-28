import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';

/// A ring showing how long the current TOTP code stays valid, with the
/// seconds left in the middle (FR-UI-02).
///
/// The ring empties as [progress] goes from 0 to 1 and turns to the theme's
/// warning colour in the last five seconds. Screen readers hear the seconds
/// left. It grows with the text size.
class OtpCountdownRing extends StatelessWidget {
  /// Creates a ring for a code with [remaining] time and [progress] elapsed.
  const OtpCountdownRing({
    super.key,
    required this.progress,
    required this.remaining,
  });

  /// Elapsed fraction of the code's period, from 0 to 1 (`OtpCode.progress`).
  final double progress;

  /// Time left before the code changes (`OtpCode.remaining`).
  final Duration remaining;

  /// From this many seconds left, the ring uses the warning colour.
  static const warningSeconds = 5;

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    final seconds = (remaining.inMilliseconds / 1000).ceil().clamp(0, 9999);
    final warning = seconds <= warningSeconds;
    final color = warning ? theme.warning : theme.primary;
    final size = MediaQuery.textScalerOf(context).scale(40);
    return Semantics(
      container: true,
      label: mfaStrings(context).secondsRemaining(seconds),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            remainingFraction: (1 - progress).clamp(0, 1).toDouble(),
            color: color,
            track: theme.outline,
          ),
          child: Center(
            child: Text(
              '$seconds',
              textDirection: TextDirection.ltr,
              style: theme.labelTextStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.remainingFraction,
    required this.color,
    required this.track,
  });

  final double remainingFraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.shortestSide / 10;
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(rect, 0, 2 * math.pi, false, paint..color = track)
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * remainingFraction,
        false,
        paint..color = color,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.remainingFraction != remainingFraction ||
      old.color != color ||
      old.track != track;
}
