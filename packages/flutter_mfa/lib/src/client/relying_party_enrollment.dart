import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:meta/meta.dart';

/// Everything a relying party (the service a user signs in to) needs to
/// enrol a user in TOTP (FR-FAC-07). Create it with
/// `MfaClient.createEnrollment`.
///
/// Show [uri] to the user (for example with `EnrollmentQrView`), ask for the
/// first code their authenticator shows and check it with [verifier] before
/// you store [secret] for the account; this proves the authenticator was
/// set up correctly.
///
/// The secret must stay on your server: verifying on the user's device is
/// not a second factor (ADR-0002). Holding this object on a device is only
/// suitable for demos and tests. [toString] never reveals the secret.
@immutable
final class RelyingPartyEnrollment {
  /// Wraps a URI and the verifier for its secret. Prefer
  /// `MfaClient.createEnrollment`, which generates both consistently.
  const RelyingPartyEnrollment({required this.uri, required this.verifier});

  /// The enrolment URI, holding the issuer, account name, parameters and
  /// secret. Render it with `uri.toUri()`; never log it.
  final OtpAuthUri uri;

  /// Checks the codes of [secret]: pass the user's first code with
  /// `lastUsedStep: null`, then persist `Accepted.nextState` to reject
  /// replays.
  final TotpVerifier verifier;

  /// The shared secret to store, encrypted, with the user's account.
  OtpSecret get secret => uri.secret;

  @override
  String toString() => 'RelyingPartyEnrollment($uri)';
}
