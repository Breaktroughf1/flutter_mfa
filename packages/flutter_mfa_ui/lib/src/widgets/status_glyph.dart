import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Small line icons drawn with [CustomPainter], because the widgets layer
/// has no icon font (ADR-0006). Always decorative: callers add the text.
enum StatusGlyph {
  /// A tick: enrolled.
  check,

  /// A circle with a bar: not enrolled.
  circle,

  /// A padlock: locked.
  lock,

  /// A triangle with an exclamation mark: needs attention.
  warning,

  /// A shield with an exclamation mark: integrity warning.
  shield,

  /// Two overlapping sheets: copy.
  copy,

  /// A counter arrow: counter-based (HOTP) account.
  counter,
}

/// Paints [glyph] in [color] at [size] logical pixels.
class StatusGlyphIcon extends StatelessWidget {
  /// Creates the icon.
  const StatusGlyphIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 18,
  });

  /// What to draw.
  final StatusGlyph glyph;

  /// Stroke colour.
  final Color color;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final StatusGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s / 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    Offset p(double x, double y) => Offset(x * s, y * s);
    switch (glyph) {
      case StatusGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(p(.15, .55).dx, p(.15, .55).dy)
            ..lineTo(p(.4, .78).dx, p(.4, .78).dy)
            ..lineTo(p(.85, .25).dx, p(.85, .25).dy),
          stroke,
        );
      case StatusGlyph.circle:
        canvas
          ..drawCircle(p(.5, .5), s * .38, stroke)
          ..drawLine(p(.32, .5), p(.68, .5), stroke);
      case StatusGlyph.lock:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(.18 * s, .45 * s, .82 * s, .9 * s),
              Radius.circular(s * .08),
            ),
            stroke,
          )
          ..drawArc(
            Rect.fromLTRB(.3 * s, .1 * s, .7 * s, .6 * s),
            math.pi,
            math.pi,
            false,
            stroke,
          );
      case StatusGlyph.warning:
        canvas
          ..drawPath(
            Path()
              ..moveTo(p(.5, .1).dx, p(.5, .1).dy)
              ..lineTo(p(.92, .88).dx, p(.92, .88).dy)
              ..lineTo(p(.08, .88).dx, p(.08, .88).dy)
              ..close(),
            stroke,
          )
          ..drawLine(p(.5, .4), p(.5, .6), stroke)
          ..drawCircle(p(.5, .75), s * .05, fill);
      case StatusGlyph.shield:
        canvas
          ..drawPath(
            Path()
              ..moveTo(p(.5, .08).dx, p(.5, .08).dy)
              ..lineTo(p(.85, .22).dx, p(.85, .22).dy)
              ..quadraticBezierTo(.85 * s, .75 * s, .5 * s, .93 * s)
              ..quadraticBezierTo(.15 * s, .75 * s, .15 * s, .22 * s)
              ..close(),
            stroke,
          )
          ..drawLine(p(.5, .32), p(.5, .55), stroke)
          ..drawCircle(p(.5, .7), s * .05, fill);
      case StatusGlyph.copy:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(.32 * s, .32 * s, .88 * s, .88 * s),
              Radius.circular(s * .08),
            ),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(p(.68, .15).dx, p(.68, .15).dy)
              ..lineTo(p(.12, .15).dx, p(.12, .15).dy)
              ..lineTo(p(.12, .7).dx, p(.12, .7).dy),
            stroke,
          );
      case StatusGlyph.counter:
        canvas
          ..drawArc(
            Rect.fromLTRB(.15 * s, .15 * s, .85 * s, .85 * s),
            -math.pi / 2,
            1.6 * math.pi,
            false,
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(p(.5, .02).dx, p(.5, .02).dy)
              ..lineTo(p(.66, .15).dx, p(.66, .15).dy)
              ..lineTo(p(.5, .28).dx, p(.5, .28).dy),
            stroke,
          );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
