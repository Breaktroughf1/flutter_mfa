import 'package:meta/meta.dart';

/// How far a [DeviceIntegrityCheck] trusts the device (FR-FAC-03).
enum IntegrityVerdict {
  /// The check found nothing wrong.
  trusted,

  /// Signs of tampering or an unusual environment (for example an emulator
  /// or a debugger) that do not prove compromise.
  suspicious,

  /// The device is rooted or jailbroken, or the app was modified.
  compromised,

  /// Nothing was checked (the default [NoopIntegrityCheck]) or the check
  /// could not decide.
  unknown,
}

/// The result of a [DeviceIntegrityCheck]: a verdict and short signal names
/// such as `'root'` or `'debugger'`, never device data or secrets.
@immutable
final class IntegrityReport {
  /// Creates a report.
  const IntegrityReport({required this.verdict, this.signals = const []});

  /// The overall verdict.
  final IntegrityVerdict verdict;

  /// Short names of what the check found, for display and logs.
  final List<String> signals;

  @override
  bool operator ==(Object other) =>
      other is IntegrityReport &&
      other.verdict == verdict &&
      _sameList(other.signals, signals);

  @override
  int get hashCode => Object.hash(verdict, Object.hashAll(signals));

  @override
  String toString() =>
      'IntegrityReport(${verdict.name}'
      '${signals.isEmpty ? '' : ', ${signals.join(', ')}'})';

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A device integrity check supplied by the app, for example one built on a
/// root-detection or attestation package (FR-FAC-03).
///
/// This is a hook for the MASVS resilience controls (MAS-R): **detection, not
/// prevention**. On a device the attacker controls, any check running in the
/// app can be bypassed, so a `trusted` verdict proves nothing. Use it to warn
/// users or to raise the bar, and keep the real protection on your server.
abstract interface class DeviceIntegrityCheck {
  /// Runs the check. Should not throw; report [IntegrityVerdict.unknown]
  /// when it cannot decide.
  Future<IntegrityReport> run();
}

/// The default check: does nothing and reports [IntegrityVerdict.unknown].
final class NoopIntegrityCheck implements DeviceIntegrityCheck {
  /// Creates the no-op check.
  const NoopIntegrityCheck();

  @override
  Future<IntegrityReport> run() async =>
      const IntegrityReport(verdict: IntegrityVerdict.unknown);
}

/// What the app does with an [IntegrityReport]: return to continue, or throw
/// to block (the exception reaches the caller of `MfaClient.create` or
/// `MfaClient.checkIntegrity`).
typedef IntegrityPolicy = Future<void> Function(IntegrityReport report);

/// The default policy: accept every report.
Future<void> allowAllIntegrity(IntegrityReport report) async {}
