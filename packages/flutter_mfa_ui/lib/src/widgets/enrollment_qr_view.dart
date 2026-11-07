import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:qr/qr.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';
import 'status_glyph.dart';

/// Shows an `otpauth://` enrolment URI as a QR code, with the setup key for
/// manual entry and a privacy warning (FR-UI-05).
///
/// For the relying-party side of enrolment: render the URI from
/// `MfaClient.createEnrollment` so users can scan it with any authenticator
/// app. The QR code is always dark on white with the standard quiet zone,
/// because many scanners cannot read inverted codes.
///
/// The setup key is grouped in fours (`JBSW Y3DP …`). A copy button appears
/// only with [onCopySecret], so the app decides how the key is copied:
/// pass `MfaClient.copySensitive` to mark the clip sensitive and clear it
/// after the expiry.
///
/// Protects against: casual exposure (warning text, no copy unless asked).
/// Does not protect against screenshots or screen recording: on Android set
/// screen-capture protection while this is shown.
class EnrollmentQrView extends StatelessWidget {
  /// Creates the view for [uri].
  const EnrollmentQrView({
    super.key,
    required this.uri,
    this.showSecret = true,
    this.onCopySecret,
  });

  /// The enrolment URI encoded in the QR code.
  final OtpAuthUri uri;

  /// Whether the setup key is shown for manual entry.
  final bool showSecret;

  /// Copies the setup key (Base32, without spaces); `null` hides the copy
  /// button.
  final ValueChanged<String>? onCopySecret;

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    final strings = mfaStrings(context);
    final copy = onCopySecret;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          image: true,
          label: strings.enrollmentQrLabel,
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth.isFinite
                  ? constraints.maxWidth.clamp(120.0, 280.0)
                  : 240.0;
              return SizedBox.square(
                dimension: side,
                child: CustomPaint(painter: _QrPainter(uri.toUri().toString())),
              );
            },
          ),
        ),
        if (showSecret) ...[
          SizedBox(height: theme.spacing * 2),
          Text(strings.setupKey, style: theme.labelTextStyle),
          SizedBox(height: theme.spacing / 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  groupSetupKey(uri.secret.toBase32()),
                  key: const ValueKey('setup-key'),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: theme.codeTextStyle.copyWith(
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (copy != null) ...[
                SizedBox(width: theme.spacing),
                Semantics(
                  container: true,
                  button: true,
                  label: strings.copySetupKey,
                  excludeSemantics: true,
                  onTap: () => copy(uri.secret.toBase32()),
                  child: GestureDetector(
                    onTap: () => copy(uri.secret.toBase32()),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox.square(
                      dimension: theme.minTapTarget,
                      child: Center(
                        child: StatusGlyphIcon(
                          StatusGlyph.copy,
                          color: theme.primary,
                          size: MediaQuery.textScalerOf(context).scale(20),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        SizedBox(height: theme.spacing * 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusGlyphIcon(
              StatusGlyph.warning,
              color: theme.warning,
              size: MediaQuery.textScalerOf(context).scale(18),
            ),
            SizedBox(width: theme.spacing),
            Flexible(
              child: Text(
                strings.enrollmentPrivacyWarning,
                style: theme.labelTextStyle.copyWith(color: theme.onSurface),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// [base32] in groups of four characters, for reading aloud or typing.
String groupSetupKey(String base32) {
  final groups = <String>[
    for (var i = 0; i < base32.length; i += 4)
      base32.substring(i, i + 4 > base32.length ? base32.length : i + 4),
  ];
  return groups.join(' ');
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data)
    : _image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );

  final String data;
  final QrImage _image;

  /// Light modules around the code, as the QR specification requires.
  static const quietZone = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final count = _image.moduleCount + quietZone * 2;
    final module = size.shortestSide / count;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final dark = Paint()..color = const Color(0xFF000000);
    for (var row = 0; row < _image.moduleCount; row++) {
      for (var col = 0; col < _image.moduleCount; col++) {
        if (_image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (col + quietZone) * module,
              (row + quietZone) * module,
              module,
              module,
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
