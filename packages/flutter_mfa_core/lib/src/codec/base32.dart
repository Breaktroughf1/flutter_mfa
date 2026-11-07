import 'dart:typed_data';

/// Base32 codec (RFC 4648 §6) with the leniency authenticator apps need.
///
/// This is the only Base32 implementation in flutter_mfa (DRY). Decoding
/// errors never include the input, because it is usually an OTP secret.
abstract final class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Padding characters required for each possible count of trailing symbols.
  static const _padFor = {0: 0, 2: 6, 4: 4, 5: 3, 7: 1};

  static const _padChar = 0x3D; // '='

  /// Encodes [bytes] as upper-case Base32.
  ///
  /// Padding is omitted by default, as `otpauth://` URIs expect
  /// (FR-OTP-04 AC3). Throws [ArgumentError] if an element is outside
  /// 0..255.
  static String encode(List<int> bytes, {bool padding = false}) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in bytes) {
      if (b < 0 || b > 255) {
        throw ArgumentError.value('<redacted>', 'bytes', 'must be 0..255');
      }
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.writeCharCode(_alphabet.codeUnitAt((buffer >> bits) & 0x1f));
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) {
      out.writeCharCode(_alphabet.codeUnitAt((buffer << (5 - bits)) & 0x1f));
    }
    if (padding) {
      while (out.length % 8 != 0) {
        out.write('=');
      }
    }
    return out.toString();
  }

  /// Decodes Base32 [input] into bytes.
  ///
  /// Lenient where real-world secrets differ (FR-OTP-04 AC2): accepts lower
  /// case, ignores spaces, tabs, newlines and hyphens, and accepts missing
  /// padding. Strict where input is ambiguous: padding must be the correct
  /// length and only at the end, and symbol counts that cannot encode whole
  /// bytes are rejected. Throws [FormatException] with the [offset] of the
  /// problem and a `null` source (the input is never echoed).
  static Uint8List decode(String input) {
    final out = BytesBuilder(copy: false);
    var buffer = 0;
    var bits = 0;
    var symbols = 0;
    var pads = 0;
    for (var i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (_isSeparator(c)) continue;
      if (c == _padChar) {
        pads++;
        continue;
      }
      if (pads > 0) {
        throw FormatException('base32 symbol after padding', null, i);
      }
      final v = _value(c);
      if (v < 0) {
        throw FormatException('invalid base32 character', null, i);
      }
      buffer = (buffer << 5) | v;
      bits += 5;
      symbols++;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((buffer >> bits) & 0xff);
      }
      buffer &= (1 << bits) - 1;
    }
    final expectedPads = _padFor[symbols % 8];
    if (expectedPads == null) {
      throw FormatException('invalid base32 length', null, input.length);
    }
    if (pads != 0 && pads != expectedPads) {
      throw FormatException('invalid base32 padding', null, input.length);
    }
    return out.takeBytes();
  }

  static bool _isSeparator(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x2D;

  static int _value(int c) {
    if (c >= 0x41 && c <= 0x5A) return c - 0x41; // A-Z
    if (c >= 0x61 && c <= 0x7A) return c - 0x61; // a-z
    if (c >= 0x32 && c <= 0x37) return c - 0x32 + 26; // 2-7
    return -1;
  }
}
