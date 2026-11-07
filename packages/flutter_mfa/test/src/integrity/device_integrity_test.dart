import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FixedCheck implements DeviceIntegrityCheck {
  _FixedCheck(this.report);
  IntegrityReport report;
  int runs = 0;
  @override
  Future<IntegrityReport> run() async {
    runs++;
    return report;
  }
}

final class _Blocked implements Exception {
  const _Blocked();
}

final class _CapturingLogger implements MfaLogger {
  final messages = <String>[];
  @override
  void log(MfaLogLevel level, String message) =>
      messages.add('${level.name}: $message');
}

void main() {
  setUp(() => MfaPlatform.instance = InMemoryMfaPlatform());

  test('the default check reports unknown and never blocks', () async {
    expect(
      await const NoopIntegrityCheck().run(),
      IntegrityReport(verdict: IntegrityVerdict.unknown),
    );
    final mfa = await MfaClient.create();
    expect(
      await mfa.checkIntegrity(),
      IntegrityReport(verdict: IntegrityVerdict.unknown),
    );
  });

  test(
    'create runs the check once and passes the report to the policy '
    '(FR-FAC-03 AC1)',
    () async {
      final check = _FixedCheck(
        IntegrityReport(
          verdict: IntegrityVerdict.suspicious,
          signals: ['emulator'],
        ),
      );
      final seen = <IntegrityReport>[];
      final logger = _CapturingLogger();
      final mfa = await MfaClient.create(
        options: MfaClientOptions(
          integrityCheck: check,
          integrityPolicy: (r) async => seen.add(r),
          logger: logger,
        ),
      );
      expect(check.runs, 1);
      expect(seen.single.signals, ['emulator']);
      expect(logger.messages, ['info: integrity suspicious']);

      check.report = IntegrityReport(
        verdict: IntegrityVerdict.compromised,
        signals: ['root'],
      );
      final report = await mfa.checkIntegrity();
      expect(report.verdict, IntegrityVerdict.compromised);
      expect(seen, hasLength(2));
      expect(logger.messages.last, 'warning: integrity compromised');
    },
  );

  test('a policy that throws blocks create and checkIntegrity', () async {
    final check = _FixedCheck(
      IntegrityReport(verdict: IntegrityVerdict.compromised),
    );
    Future<void> policy(IntegrityReport r) async {
      if (r.verdict == IntegrityVerdict.compromised) throw const _Blocked();
    }

    await expectLater(
      MfaClient.create(
        options: MfaClientOptions(
          integrityCheck: check,
          integrityPolicy: policy,
        ),
      ),
      throwsA(isA<_Blocked>()),
    );

    check.report = IntegrityReport(verdict: IntegrityVerdict.trusted);
    final mfa = await MfaClient.create(
      options: MfaClientOptions(integrityCheck: check, integrityPolicy: policy),
    );
    check.report = IntegrityReport(verdict: IntegrityVerdict.compromised);
    await expectLater(mfa.checkIntegrity(), throwsA(isA<_Blocked>()));
    await mfa.dispose();
    expect(mfa.checkIntegrity, throwsStateError);
  });

  test('a report keeps a copy of the signals and cannot be changed', () {
    final signals = ['root'];
    final report = IntegrityReport(
      verdict: IntegrityVerdict.compromised,
      signals: signals,
    );
    signals.add('later');
    expect(report.signals, ['root']);
    expect(() => report.signals.add('x'), throwsUnsupportedError);
  });

  test('reports compare by value and print only the verdict and signals', () {
    final a = IntegrityReport(
      verdict: IntegrityVerdict.compromised,
      signals: ['root', 'hooks'],
    );
    expect(
      a,
      IntegrityReport(
        verdict: IntegrityVerdict.compromised,
        signals: ['root', 'hooks'],
      ),
    );
    expect(a.hashCode, isNot(0));
    expect(
      a,
      isNot(
        IntegrityReport(
          verdict: IntegrityVerdict.compromised,
          signals: ['root'],
        ),
      ),
    );
    expect(
      a,
      isNot(
        IntegrityReport(
          verdict: IntegrityVerdict.compromised,
          signals: ['root', 'other'],
        ),
      ),
    );
    expect(a.toString(), 'IntegrityReport(compromised, root, hooks)');
    expect(
      IntegrityReport(verdict: IntegrityVerdict.trusted).toString(),
      'IntegrityReport(trusted)',
    );
  });
}
