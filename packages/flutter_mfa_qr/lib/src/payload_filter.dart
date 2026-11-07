import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

/// The outcome of one detected QR payload.
sealed class ScanResult {
  const ScanResult();
}

/// The payload is a valid `otpauth://` URI.
final class ScanAccepted extends ScanResult {
  /// Wraps [uri].
  const ScanAccepted(this.uri);

  /// The parsed URI (its `toString` redacts the secret).
  final OtpAuthUri uri;
}

/// The payload is not a valid `otpauth://` URI.
final class ScanRejected extends ScanResult {
  /// Wraps [payload].
  const ScanRejected(this.payload);

  /// The raw payload, which may contain a secret: never log it.
  final String payload;
}

/// Accepts only `otpauth://` payloads and drops repeated detections of the
/// same code (FR-QR-01).
///
/// A payload seen again within [window] of its previous sighting is a
/// duplicate, so a code held in front of the camera is reported once. Only a
/// SHA-256 digest of the last payload is kept, never the payload itself.
final class PayloadFilter {
  /// Creates a filter with an empty history.
  PayloadFilter({
    this.clock = const SystemClock(),
    this.window = const Duration(seconds: 2),
  });

  /// Time source for the duplicate window.
  final Clock clock;

  /// How long a payload counts as a duplicate after it was last seen.
  final Duration window;

  Digest? _last;
  DateTime? _lastSeen;

  /// The result for [payload], or `null` for an empty payload or a duplicate.
  ScanResult? check(String payload) {
    if (payload.isEmpty) return null;
    final now = clock.now();
    final digest = sha256.convert(utf8.encode(payload));
    final lastSeen = _lastSeen;
    final duplicate =
        digest == _last &&
        lastSeen != null &&
        now.difference(lastSeen) < window;
    _last = digest;
    _lastSeen = now;
    if (duplicate) return null;
    final uri = OtpAuthUri.tryParse(payload);
    return uri == null ? ScanRejected(payload) : ScanAccepted(uri);
  }
}
