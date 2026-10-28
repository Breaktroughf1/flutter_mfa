import 'package:meta/meta.dart';

import '../errors/mfa_exception.dart';
import '../otp/hotp.dart';
import '../otp/otp_algorithm.dart';
import '../otp/otp_secret.dart';
import '../otp/totp.dart';

/// Ways an `otpauth://` URI may not work in common authenticator apps.
///
/// The Key URI format is a de-facto standard (G10); many apps ignore
/// `algorithm`, `digits` and `period` and silently generate wrong codes.
enum CompatibilityWarning {
  /// Algorithm is not SHA-1.
  nonDefaultAlgorithm,

  /// Digits is not 6.
  nonDefaultDigits,

  /// TOTP period is not 30 seconds.
  nonDefaultPeriod,

  /// The `issuer` parameter and the label prefix differed; the parameter won.
  issuerMismatch,

  /// The secret is shorter than the RFC 4226 minimum of 128 bits.
  shortSecret,
}

/// An `otpauth://totp|hotp/<label>?…` enrolment URI (Google Key URI format).
///
/// This is the only URI parser and generator in flutter_mfa (DRY). The URI
/// contains the secret, so [toString] is redacted: use [toUri] explicitly
/// when rendering a QR code, and never log it.
@immutable
final class OtpAuthUri {
  /// Creates a URI model. Values are validated by [toUri].
  const OtpAuthUri({
    required this.type,
    required this.secret,
    required this.accountName,
    this.issuer,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = const Duration(seconds: 30),
    this.counter,
    this.extras = const {},
  }) : _issuerMismatch = false;

  const OtpAuthUri._parsed({
    required this.type,
    required this.secret,
    required this.accountName,
    required this.issuer,
    required this.algorithm,
    required this.digits,
    required this.period,
    required this.counter,
    required this.extras,
    required bool issuerMismatch,
  }) : _issuerMismatch = issuerMismatch;

  /// Parses [uri] strictly on structure and leniently on optional values.
  ///
  /// Accepts label `Issuer:account` (literal or `%3A` separator), any letter
  /// case for scheme, type, algorithm and known parameter names, and
  /// preserves unknown parameters in [extras]. The `issuer` parameter wins
  /// over a different label prefix ([CompatibilityWarning.issuerMismatch]).
  /// A `counter` on TOTP and a `period` on HOTP are ignored.
  ///
  /// Throws [OtpAuthUriException] (a `FormatException`, never containing the
  /// input) for anything else (FR-URI-01).
  factory OtpAuthUri.parse(String uri) {
    if (_badPercent.hasMatch(uri)) {
      throw const OtpAuthUriException(
        field: 'uri',
        reason: 'malformed percent-encoding',
      );
    }
    final Uri parsed;
    final Map<String, List<String>> query;
    try {
      parsed = Uri.parse(uri);
      query = parsed.queryParametersAll;
    } on FormatException {
      throw const OtpAuthUriException(field: 'uri', reason: 'not a valid URI');
    }
    if (parsed.scheme.toLowerCase() != 'otpauth') {
      throw const OtpAuthUriException(
        field: 'scheme',
        reason: 'must be otpauth',
      );
    }
    final type = switch (parsed.host.toLowerCase()) {
      'totp' => OtpType.totp,
      'hotp' => OtpType.hotp,
      _ => throw const OtpAuthUriException(
        field: 'type',
        reason: 'must be totp or hotp',
      ),
    };

    final (labelIssuer, accountName) = _parseLabel(parsed.path);

    final known = <String, String>{};
    final extras = <String, String>{};
    for (final MapEntry(:key, :value) in query.entries) {
      final lower = key.toLowerCase();
      if (!_knownParams.contains(lower)) {
        extras[key] = value.last;
        continue;
      }
      if (value.length > 1 || known.containsKey(lower)) {
        throw OtpAuthUriException(
          field: lower,
          reason: 'appears more than once',
        );
      }
      known[lower] = value.single;
    }

    final secretText = known['secret'];
    if (secretText == null || secretText.isEmpty) {
      throw const OtpAuthUriException(field: 'secret', reason: 'missing');
    }
    final OtpSecret secret;
    try {
      secret = OtpSecret.fromBase32(secretText);
    } on OtpConfigException {
      throw const OtpAuthUriException(
        field: 'secret',
        reason: 'not valid base32 of 10 to 256 bytes',
      );
    }

    final issuerParam = known['issuer'];
    final issuer = (issuerParam != null && issuerParam.isNotEmpty)
        ? issuerParam
        : labelIssuer;
    final mismatch =
        issuerParam != null &&
        labelIssuer != null &&
        issuerParam != labelIssuer;

    final algorithm = switch (known['algorithm']?.toUpperCase()) {
      null || 'SHA1' => OtpAlgorithm.sha1,
      'SHA256' => OtpAlgorithm.sha256,
      'SHA512' => OtpAlgorithm.sha512,
      _ => throw const OtpAuthUriException(
        field: 'algorithm',
        reason: 'must be SHA1, SHA256 or SHA512',
      ),
    };

    final digitsText = known['digits'];
    final digits = digitsText == null ? 6 : _uint(digitsText, 'digits');
    if (digits < 6 || digits > 8) {
      throw const OtpAuthUriException(
        field: 'digits',
        reason: 'must be 6, 7 or 8',
      );
    }

    var period = const Duration(seconds: 30);
    int? counter;
    if (type == OtpType.totp) {
      final periodText = known['period'];
      if (periodText != null) {
        final seconds = _uint(periodText, 'period');
        if (seconds < 1) {
          throw const OtpAuthUriException(
            field: 'period',
            reason: 'must be at least 1 second',
          );
        }
        period = Duration(seconds: seconds);
      }
    } else {
      final counterText = known['counter'];
      if (counterText == null) {
        throw const OtpAuthUriException(
          field: 'counter',
          reason: 'required for hotp',
        );
      }
      counter = _uint(counterText, 'counter');
      if (counter > Hotp.maxCounter) {
        throw const OtpAuthUriException(
          field: 'counter',
          reason: 'must be at most 2^53-1',
        );
      }
    }

    return OtpAuthUri._parsed(
      type: type,
      secret: secret,
      accountName: accountName,
      issuer: issuer,
      algorithm: algorithm,
      digits: digits,
      period: period,
      counter: counter,
      extras: Map.unmodifiable(extras),
      issuerMismatch: mismatch,
    );
  }

  /// Like [OtpAuthUri.parse] but returns `null` for invalid input.
  static OtpAuthUri? tryParse(String uri) {
    try {
      return OtpAuthUri.parse(uri);
    } on FormatException {
      return null;
    }
  }

  /// TOTP or HOTP.
  final OtpType type;

  /// The shared secret.
  final OtpSecret secret;

  /// Account name shown to the user, for example an email address.
  final String accountName;

  /// Service name, or `null`.
  final String? issuer;

  /// HMAC algorithm.
  final OtpAlgorithm algorithm;

  /// Code length (6–8).
  final int digits;

  /// TOTP period (ignored for HOTP).
  final Duration period;

  /// HOTP counter; `null` for TOTP.
  final int? counter;

  /// Unknown query parameters, preserved (for example `image`).
  final Map<String, String> extras;

  final bool _issuerMismatch;

  /// Portability problems with this URI in common authenticator apps
  /// (FR-URI-02 AC2).
  List<CompatibilityWarning> get compatibilityWarnings => [
    if (algorithm != OtpAlgorithm.sha1)
      CompatibilityWarning.nonDefaultAlgorithm,
    if (digits != 6) CompatibilityWarning.nonDefaultDigits,
    if (type == OtpType.totp && period != const Duration(seconds: 30))
      CompatibilityWarning.nonDefaultPeriod,
    if (_issuerMismatch) CompatibilityWarning.issuerMismatch,
    if (!secret.meetsRfcMinimum) CompatibilityWarning.shortSecret,
  ];

  /// TOTP parameters, or `null` for HOTP.
  TotpConfig? get totpConfig => type == OtpType.totp
      ? TotpConfig(algorithm: algorithm, digits: digits, period: period)
      : null;

  /// HOTP parameters, or `null` for TOTP.
  HotpConfig? get hotpConfig => type == OtpType.hotp
      ? HotpConfig(algorithm: algorithm, digits: digits)
      : null;

  /// Builds the URI. Contains the secret: render it as a QR code, never log
  /// or persist it.
  ///
  /// Emits only non-default parameters, plus `issuer` in both the label and
  /// the parameter. Throws [OtpAuthUriException] for an empty account name,
  /// a colon in the issuer or account name, invalid digits, period or
  /// counter, or an extra parameter that shadows a known one.
  Uri toUri() {
    if (accountName.isEmpty || accountName.contains(':')) {
      throw const OtpAuthUriException(
        field: 'label',
        reason: 'account name must be non-empty without colons',
      );
    }
    final issuer = this.issuer;
    if (issuer != null && (issuer.isEmpty || issuer.contains(':'))) {
      throw const OtpAuthUriException(
        field: 'issuer',
        reason: 'must be non-empty without colons',
      );
    }
    if (digits < 6 || digits > 8) {
      throw const OtpAuthUriException(
        field: 'digits',
        reason: 'must be 6, 7 or 8',
      );
    }
    final periodMs = period.inMilliseconds;
    if (type == OtpType.totp && (periodMs < 1000 || periodMs % 1000 != 0)) {
      throw const OtpAuthUriException(
        field: 'period',
        reason: 'must be a positive whole number of seconds',
      );
    }
    final counter = this.counter;
    if (type == OtpType.hotp &&
        (counter == null || counter < 0 || counter > Hotp.maxCounter)) {
      throw const OtpAuthUriException(
        field: 'counter',
        reason: 'required for hotp, 0 to 2^53-1',
      );
    }
    if (extras.keys.any((k) => _knownParams.contains(k.toLowerCase()))) {
      throw const OtpAuthUriException(
        field: 'extras',
        reason: 'must not repeat a known parameter',
      );
    }

    final label = issuer == null
        ? Uri.encodeComponent(accountName)
        : '${Uri.encodeComponent(issuer)}:${Uri.encodeComponent(accountName)}';
    final params = <String>[
      'secret=${secret.toBase32()}',
      if (issuer != null) 'issuer=${Uri.encodeComponent(issuer)}',
      if (algorithm != OtpAlgorithm.sha1)
        'algorithm=${algorithm.name.toUpperCase()}',
      if (digits != 6) 'digits=$digits',
      if (type == OtpType.totp && periodMs != 30000)
        'period=${period.inSeconds}',
      if (type == OtpType.hotp) 'counter=$counter',
      for (final key in extras.keys.toList()..sort())
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(extras[key]!)}',
    ];
    return Uri.parse('otpauth://${type.name}/$label?${params.join('&')}');
  }

  @override
  bool operator ==(Object other) =>
      other is OtpAuthUri &&
      other.type == type &&
      other.secret == secret &&
      other.accountName == accountName &&
      other.issuer == issuer &&
      other.algorithm == algorithm &&
      other.digits == digits &&
      other.period == period &&
      other.counter == counter &&
      other.extras.length == extras.length &&
      extras.entries.every((e) => other.extras[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    type,
    secret,
    accountName,
    issuer,
    algorithm,
    digits,
    period,
    counter,
    Object.hashAllUnordered(
      extras.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  /// Redacted description; never contains the secret.
  @override
  String toString() =>
      'OtpAuthUri(${type.name}, ${issuer == null ? '' : '$issuer:'}$accountName, '
      'secret: <redacted ${secret.length}B>)';

  static const _knownParams = {
    'secret',
    'issuer',
    'algorithm',
    'digits',
    'period',
    'counter',
  };
  static final _badPercent = RegExp('%(?![0-9A-Fa-f]{2})');
  static final _digitsOnly = RegExp(r'^[0-9]{1,16}$');

  static (String?, String) _parseLabel(String rawPath) {
    final raw = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    final literal = raw.indexOf(':');
    final encoded = raw.toUpperCase().indexOf('%3A');
    final (split, width) = switch ((literal, encoded)) {
      (-1, -1) => (-1, 0),
      (-1, final e) => (e, 3),
      (final l, -1) => (l, 1),
      (final l, final e) => l < e ? (l, 1) : (e, 3),
    };
    final String? issuer;
    final String account;
    try {
      issuer = split < 0
          ? null
          : Uri.decodeComponent(raw.substring(0, split)).trim();
      account = Uri.decodeComponent(
        split < 0 ? raw : raw.substring(split + width),
      ).trim();
    } on FormatException {
      throw const OtpAuthUriException(
        field: 'label',
        reason: 'malformed percent-encoding',
      );
    }
    if (account.isEmpty) {
      throw const OtpAuthUriException(
        field: 'label',
        reason: 'account name is missing',
      );
    }
    return ((issuer == null || issuer.isEmpty) ? null : issuer, account);
  }

  static int _uint(String text, String field) {
    if (!_digitsOnly.hasMatch(text)) {
      throw OtpAuthUriException(
        field: field,
        reason: 'must be a non-negative integer',
      );
    }
    return int.parse(text);
  }
}
