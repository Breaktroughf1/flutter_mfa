import 'dart:async';

import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa/src/client/code_ticker.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret20 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // RFC 6238 test secret

final class _Log implements MfaLogger {
  final lines = <String>[];
  @override
  void log(MfaLogLevel level, String message) => lines.add(message);
}

void main() {
  late InMemoryMfaPlatform vault;
  late FakeClock clock;
  late _Log log;

  setUp(() {
    vault = InMemoryMfaPlatform();
    MfaPlatform.instance = vault;
    // 58.5 s after the epoch: step 1 (30–59 s), 1.5 s before step 2.
    clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(58500, isUtc: true));
    log = _Log();
  });

  Future<MfaClient> client({Duration expiry = const Duration(seconds: 30)}) =>
      MfaClient.create(
        options: MfaClientOptions(
          clock: clock,
          logger: log,
          clipboardExpiry: expiry,
        ),
      );

  /// Advances the fake clock and the test's fake timers together.
  Future<void> advance(WidgetTester tester, Duration duration) async {
    const step = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < duration; t += step) {
      clock.advance(step);
      await tester.pump(step);
    }
  }

  testWidgets(
    'emits now, every second, and once per step change (FR-FAC-02 AC1)',
    (
      tester,
    ) async {
      final mfa = await client();
      final a = await mfa.enrollManual(
        secretBase32: _secret20,
        accountName: 'a',
      );
      final codes = <OtpCode>[];
      final sub = mfa.codeStream(a.id).listen(codes.add);
      await tester.pump();
      expect(codes, hasLength(1));
      expect(codes.single.value, '287082', reason: 'RFC 6238 at T=59 (step 1)');
      expect(codes.single.remaining, const Duration(milliseconds: 1500));

      await advance(tester, const Duration(seconds: 3)); // 58.5 → 61.5 s
      expect(codes.map((c) => c.step), [1, 1, 2, 2]);
      expect(
        [
          for (var i = 1; i < codes.length; i++)
            codes[i].value != codes[i - 1].value,
        ].where((changed) => changed),
        hasLength(1),
        reason: 'exactly one change, at the 60 s boundary',
      );
      expect(codes[2].remaining, const Duration(seconds: 30));
      expect(codes.last.remaining, const Duration(seconds: 29));
      // Not awaited: under the test's fake async, cancel()'s root-zone future
      // never completes.
      unawaited(sub.cancel());
      await tester.pump();
    },
  );

  testWidgets('cancelling stops the timer (AC2)', (tester) async {
    final mfa = await client();
    final a = await mfa.enrollManual(secretBase32: _secret20, accountName: 'a');
    final codes = <OtpCode>[];
    final sub = mfa.codeStream(a.id).listen(codes.add);
    await advance(tester, const Duration(seconds: 2));
    final seen = codes.length;
    // Not awaited: under the test's fake async, cancel()'s root-zone future
    // never completes.
    unawaited(sub.cancel());
    await tester.pump();
    await advance(tester, const Duration(seconds: 3));
    expect(codes, hasLength(seen));
    // testWidgets fails if a timer is still pending here.
  });

  testWidgets('all code streams of a client share one ticker (02 §8)', (
    tester,
  ) async {
    final ticker = CodeTicker(clock);
    final a = <DateTime>[];
    final b = <DateTime>[];
    final subA = ticker.ticks.listen(a.add);
    final subB = ticker.ticks.listen(b.add);
    await advance(tester, const Duration(seconds: 3));
    expect(a, hasLength(3));
    expect(
      [for (var i = 0; i < 3; i++) identical(a[i], b[i])],
      [
        true,
        true,
        true,
      ],
      reason: 'one tick fanned out, not one timer per listener',
    );
    expect(a.map((t) => t.millisecondsSinceEpoch % 1000), [0, 0, 0]);
    unawaited(subA.cancel());
    unawaited(subB.cancel());
    await tester.pump();
    // testWidgets fails if the timer is still pending here.
  });

  testWidgets('a clock before T0 is a stream error, now or at a later tick', (
    tester,
  ) async {
    clock = FakeClock(DateTime.utc(1970, 1, 1, 0, 0, 1, 500));
    final mfa = await client();
    final a = await mfa.enrollManual(secretBase32: _secret20, accountName: 'a');
    final errors = <Object>[];
    var done = false;
    final codes = <OtpCode>[];
    mfa
        .codeStream(a.id)
        .listen(codes.add, onError: errors.add, onDone: () => done = true);
    await tester.pump();
    expect(codes, hasLength(1));

    clock.time = DateTime.utc(1969, 12, 31, 23, 59, 59); // set backwards
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      errors.single,
      isA<OtpConfigException>().having((e) => e.field, 'field', 'time'),
    );
    expect(done, isTrue);

    errors.clear();
    mfa
        .codeStream(a.id)
        .listen((_) {}, onError: errors.add, onDone: () => done = true);
    await tester.pump();
    expect(errors.single, isA<OtpConfigException>());
  });

  testWidgets('disposing the client closes its live code streams', (
    tester,
  ) async {
    final mfa = await client();
    final a = await mfa.enrollManual(secretBase32: _secret20, accountName: 'a');
    var done = false;
    mfa.codeStream(a.id).listen((_) {}, onDone: () => done = true);
    await tester.pump();
    unawaited(mfa.dispose());
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('cancelling before the secret is read emits nothing', (
    tester,
  ) async {
    final mfa = await client();
    final a = await mfa.enrollManual(secretBase32: _secret20, accountName: 'a');
    final codes = <OtpCode>[];
    final sub = mfa.codeStream(a.id).listen(codes.add);
    // Not awaited: under the test's fake async, cancel()'s root-zone future
    // never completes.
    unawaited(sub.cancel());
    await tester.pump();
    await advance(tester, const Duration(seconds: 2));
    expect(codes, isEmpty);
  });

  testWidgets('a protected account prompts once per subscription', (
    tester,
  ) async {
    final mfa = await client();
    final a = await mfa.enrollManual(
      secretBase32: _secret20,
      accountName: 'a',
      protection: ProtectionLevel.biometric,
    );
    final sub = mfa
        .codeStream(a.id, prompt: const BiometricPrompt(title: 'Show code'))
        .listen((_) {});
    await advance(tester, const Duration(seconds: 3));
    expect(vault.prompts, [const BiometricPrompt(title: 'Show code')]);
    // Not awaited: under the test's fake async, cancel()'s root-zone future
    // never completes.
    unawaited(sub.cancel());
    await tester.pump();
  });

  testWidgets('errors arrive on the stream, which then closes', (tester) async {
    final mfa = await client();
    final hotp = await mfa.enrollManual(
      secretBase32: _secret20,
      accountName: 'h',
      type: OtpType.hotp,
    );
    Future<Object?> firstError(Stream<OtpCode> stream) async {
      Object? error;
      var done = false;
      stream.listen(
        (_) {},
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );
      await tester.pump();
      expect(done, isTrue);
      return error;
    }

    expect(
      await firstError(mfa.codeStream(hotp.id)),
      isA<OtpConfigException>().having((e) => e.field, 'field', 'type'),
    );
    expect(await firstError(mfa.codeStream('missing')), const VaultNotFound());
    final protected = await mfa.enrollManual(
      secretBase32: _secret20,
      accountName: 'p',
      protection: ProtectionLevel.biometric,
    );
    vault.onBiometricPrompt = (_) => false;
    expect(
      await firstError(mfa.codeStream(protected.id)),
      const VaultUserCancelled(),
    );
  });

  test('a disposed client refuses codeStream and copying', () async {
    final mfa = await client();
    await mfa.dispose();
    expect(() => mfa.codeStream('a'), throwsStateError);
    expect(() => mfa.copySensitive('x'), throwsStateError);
  });

  test('copyCode copies the current code sensitively and never logs it '
      '(FR-FAC-05)', () async {
    final mfa = await client(expiry: const Duration(seconds: 45));
    final a = await mfa.enrollManual(secretBase32: _secret20, accountName: 'a');
    await mfa.copyCode(a.id);
    expect(vault.clipboard, ('287082', const Duration(seconds: 45)));
    expect(log.lines, contains('copied code of ${a.id}'));
    expect(log.lines.join(), isNot(contains('287082')));
  });

  test('copyCode on a counter-based account uses up the next code', () async {
    final mfa = await client();
    final h = await mfa.enrollManual(
      secretBase32: _secret20,
      accountName: 'h',
      type: OtpType.hotp,
    );
    await mfa.copyCode(h.id);
    expect(vault.clipboard!.$1, rfc4226Vectors.first.code);
    expect((await mfa.accounts()).single.counter, 1);
  });

  test('copySensitive copies any text with the configured expiry', () async {
    final mfa = await client();
    await mfa.copySensitive(_secret20);
    expect(vault.clipboard, (_secret20, const Duration(seconds: 30)));
  });
}
