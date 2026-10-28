import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret20 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // RFC 4226 test secret

final class _CapturingLogger implements MfaLogger {
  final messages = <String>[];
  @override
  void log(MfaLogLevel level, String message) =>
      messages.add('${level.name}: $message');
}

void main() {
  late InMemoryMfaPlatform vault;
  late FakeClock clock;
  late _CapturingLogger logger;

  setUp(() {
    vault = InMemoryMfaPlatform();
    MfaPlatform.instance = vault;
    clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true));
    logger = _CapturingLogger();
  });

  Future<MfaClient> client() => MfaClient.create(
    options: MfaClientOptions(clock: clock, logger: logger),
  );

  group('enrolment (UC1, UC2)', () {
    test(
      'enrol from URI → list → code matches core → remove (FR-FAC-01)',
      () async {
        final mfa = await client();
        final account = await mfa.enrollFromUri(
          'otpauth://totp/Example:alice?secret=$_secret20&issuer=Example&digits=8',
        );
        expect(account.issuer, 'Example');
        expect(account.accountName, 'alice');
        expect(account.digits, 8);
        expect(account.createdAt, clock.now());
        expect(await mfa.accounts(), [account]);

        final code = await mfa.currentCode(account.id);
        expect(code.value, '94287082', reason: 'RFC 6238 vector at T=59');
        expect(code.step, 1);
        expect(code.remaining, const Duration(seconds: 1));
        expect(code.progress, closeTo(29 / 30, 1e-9));

        await mfa.remove(account.id);
        expect(await mfa.accounts(), isEmpty);
        expect(await vault.keys(), [
          '__index_v1__',
        ], reason: 'secret deleted too');
      },
    );

    test('removing one account keeps the others and their secrets', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20');
      final b = await mfa.enrollFromUri('otpauth://totp/b?secret=$_secret20');
      await mfa.remove(a.id);
      expect(await mfa.accounts(), [b]);
      expect(
        await vault.keys(),
        unorderedEquals(['__index_v1__', 'acct_${b.id}']),
      );
      expect((await mfa.currentCode(b.id)).value, hasLength(6));
    });

    test(
      'secrets are stored as bytes separately from the metadata (FR-VLT-01)',
      () async {
        final mfa = await client();
        final account = await mfa.enrollFromUri(
          'otpauth://totp/alice?secret=$_secret20',
        );
        final stored = await vault.read('acct_${account.id}');
        expect(stored, utf8.encode('12345678901234567890'));
        final index = utf8.decode((await vault.read('__index_v1__'))!);
        expect(index, isNot(contains(_secret20)));
        expect(index, isNot(contains('1234567890')));
      },
    );

    test('manual enrolment with TOTP and HOTP configuration', () async {
      final mfa = await client();
      final t = await mfa.enrollManual(
        secretBase32: 'gezd gnbv gy3t qojq gezd gnbv gy3t qojq',
        accountName: '  bob  ',
        issuer: '  ',
        totp: const TotpConfig(
          algorithm: OtpAlgorithm.sha256,
          digits: 7,
          period: Duration(seconds: 60),
        ),
      );
      expect(
        (t.accountName, t.issuer, t.algorithm, t.digits, t.period),
        ('bob', null, OtpAlgorithm.sha256, 7, const Duration(seconds: 60)),
      );
      final h = await mfa.enrollManual(
        secretBase32: _secret20,
        accountName: 'carol',
        issuer: 'Ex',
        type: OtpType.hotp,
        counter: 5,
      );
      expect((h.type, h.counter, h.issuer), (OtpType.hotp, 5, 'Ex'));
      final h0 = await mfa.enrollManual(
        secretBase32: _secret20,
        accountName: 'dave',
        type: OtpType.hotp,
        hotp: const HotpConfig(digits: 8),
      );
      expect((h0.counter, h0.digits), (0, 8));
    });

    test('invalid input is rejected before anything is stored', () async {
      final mfa = await client();
      await expectLater(
        mfa.enrollFromUri('https://example.com'),
        throwsA(isA<OtpAuthUriException>()),
      );
      await expectLater(
        () => mfa.enrollManual(secretBase32: 'not base32!', accountName: 'a'),
        throwsA(isA<OtpConfigException>()),
      );
      await expectLater(
        mfa.enrollManual(secretBase32: _secret20, accountName: '   '),
        throwsA(isA<OtpConfigException>()),
      );
      await expectLater(
        mfa.enrollManual(
          secretBase32: _secret20,
          accountName: 'a',
          totp: const TotpConfig(digits: 9),
        ),
        throwsA(isA<OtpConfigException>()),
      );
      expect(await vault.keys(), isEmpty);
    });

    test(
      'an unsupported protection level is refused, never downgraded (fail closed)',
      () async {
        vault.currentCapabilities = const VaultCapabilities(
          hardwareBacked: true,
          strongBox: false,
          secureEnclave: false,
          biometricsEnrolled: false,
          secureContext: true,
          persistentStorage: true,
          screenCaptureProtection: false,
          supportedLevels: {ProtectionLevel.standard},
        );
        final mfa = await client();
        await expectLater(
          mfa.enrollFromUri(
            'otpauth://totp/a?secret=$_secret20',
            protection: ProtectionLevel.biometric,
          ),
          throwsA(isA<VaultHardwareUnavailable>()),
        );
        expect(await vault.keys(), isEmpty);
        expect(await mfa.accounts(), isEmpty);
      },
    );

    test('if the index write fails the secret is removed again', () async {
      final mfa = await client();
      vault.failNext(
        VaultOperation.write,
        const VaultCorrupted(),
        key: '__index_v1__',
      );
      await expectLater(
        mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20'),
        throwsA(const VaultCorrupted()),
      );
      expect(await vault.keys(), isEmpty, reason: 'no orphaned secret');
      expect(await mfa.accounts(), isEmpty);
    });

    test('if the secret write fails nothing is stored', () async {
      final mfa = await client();
      vault.failNext(VaultOperation.write, const VaultCorrupted());
      await expectLater(
        mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20'),
        throwsA(const VaultCorrupted()),
      );
      expect(await vault.keys(), isEmpty);
    });

    test('concurrent enrolments do not lose entries', () async {
      final mfa = await client();
      await Future.wait([
        for (var i = 0; i < 20; i++)
          mfa.enrollManual(secretBase32: _secret20, accountName: 'user$i'),
      ]);
      expect(await mfa.accounts(), hasLength(20));
      final fresh = await client();
      expect(await fresh.accounts(), hasLength(20));
    });
  });

  group('protected accounts (FR-VLT-05/06)', () {
    test(
      'biometric accounts show the default prompt or the given one',
      () async {
        final mfa = await client();
        final a = await mfa.enrollFromUri(
          'otpauth://totp/a?secret=$_secret20',
          protection: ProtectionLevel.biometric,
        );
        expect(vault.levelOf('acct_${a.id}'), ProtectionLevel.biometric);
        expect(vault.levelOf('__index_v1__'), ProtectionLevel.standard);
        await mfa.currentCode(a.id);
        expect(vault.prompts.last, const BiometricPrompt(title: 'Unlock code'));
        await mfa.currentCode(
          a.id,
          prompt: const BiometricPrompt(title: 'Custom'),
        );
        expect(vault.prompts.last, const BiometricPrompt(title: 'Custom'));
      },
    );

    test('a cancelled prompt surfaces as VaultUserCancelled', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri(
        'otpauth://totp/a?secret=$_secret20',
        protection: ProtectionLevel.hardwareBound,
      );
      vault.onBiometricPrompt = (_) => false;
      await expectLater(
        mfa.currentCode(a.id),
        throwsA(const VaultUserCancelled()),
      );
    });

    test('standard accounts never show a prompt', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20');
      await mfa.currentCode(a.id);
      expect(vault.prompts, isEmpty);
    });
  });

  group('HOTP', () {
    test(
      'each code advances and persists the counter before returning',
      () async {
        final mfa = await client();
        final a = await mfa.enrollFromUri(
          'otpauth://hotp/a?secret=$_secret20&counter=0',
        );
        final codes = [
          for (var i = 0; i < 3; i++) (await mfa.currentCode(a.id)).value,
        ];
        expect(codes, rfc4226Vectors.take(3).map((v) => v.code));
        final fresh = await client();
        expect((await fresh.accounts()).single.counter, 3);
        final c = await fresh.currentCode(a.id);
        expect((c.step, c.remaining, c.progress), (3, Duration.zero, 0.0));
      },
    );
  });

  group('index integrity', () {
    test('the index persists across client re-creation', () async {
      final first = await client();
      final a = await first.enrollFromUri('otpauth://totp/a?secret=$_secret20');
      await first.dispose();
      final second = await client();
      expect(await second.accounts(), [a]);
    });

    test(
      'a corrupted index surfaces as VaultCorrupted and is recoverable via wipeAll',
      () async {
        await vault.write(
          '__index_v1__',
          Uint8List.fromList(utf8.encode('{"v":1,"accounts":[{"v":1}]}')),
          ProtectionLevel.standard,
        );
        final mfa = await client();
        await expectLater(mfa.accounts(), throwsA(const VaultCorrupted()));
        await mfa.wipeAll();
        expect(await mfa.accounts(), isEmpty);
      },
    );

    test(
      'garbage, wrong versions and duplicate ids are all VaultCorrupted',
      () async {
        final good = OtpAccount(
          id: OtpAccount.generateId(),
          type: OtpType.totp,
          accountName: 'a',
          createdAt: DateTime.utc(2026),
        ).toJson();
        for (final raw in [
          [0xff, 0xfe],
          utf8.encode('not json'),
          utf8.encode('[]'),
          utf8.encode('{"v":2,"accounts":[]}'),
          utf8.encode('{"v":1,"accounts":[1]}'),
          utf8.encode(
            jsonEncode({
              'v': 1,
              'accounts': [good, good],
            }),
          ),
        ]) {
          final v = InMemoryMfaPlatform();
          MfaPlatform.instance = v;
          await v.write(
            '__index_v1__',
            Uint8List.fromList(raw),
            ProtectionLevel.standard,
          );
          final mfa = await client();
          await expectLater(
            mfa.accounts(),
            throwsA(const VaultCorrupted()),
            reason: '$raw',
          );
        }
      },
    );

    test('a missing secret for an indexed account is VaultCorrupted', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20');
      await vault.delete('acct_${a.id}');
      await expectLater(mfa.currentCode(a.id), throwsA(const VaultCorrupted()));
    });

    test('a stored secret of invalid length is VaultCorrupted', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20');
      await vault.write('acct_${a.id}', Uint8List(3), ProtectionLevel.standard);
      await expectLater(mfa.currentCode(a.id), throwsA(const VaultCorrupted()));
    });

    test('orphaned secrets are swept when the index is first loaded', () async {
      await vault.write(
        'acct_00000000-0000-4000-8000-000000000000',
        Uint8List(20),
        ProtectionLevel.standard,
      );
      await vault.write('unrelated', Uint8List(1), ProtectionLevel.standard);
      final mfa = await client();
      expect(await mfa.accounts(), isEmpty);
      expect(await vault.keys(), ['unrelated']);
    });
  });

  group('errors pass through as typed VaultExceptions (FR-VLT-07)', () {
    test('creating a client fails when the vault is unavailable', () async {
      vault.failNext(
        VaultOperation.capabilities,
        const VaultUnavailable(VaultUnavailableReason.insecureContext),
      );
      await expectLater(
        client(),
        throwsA(const VaultUnavailable(VaultUnavailableReason.insecureContext)),
      );
    });

    test('unknown ids are VaultNotFound everywhere', () async {
      final mfa = await client();
      await expectLater(
        mfa.currentCode('nope'),
        throwsA(const VaultNotFound()),
      );
      await expectLater(mfa.remove('nope'), throwsA(const VaultNotFound()));
      await expectLater(
        mfa.rename('nope', accountName: 'x'),
        throwsA(const VaultNotFound()),
      );
    });

    test('key invalidation reaches the caller unchanged', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri(
        'otpauth://totp/a?secret=$_secret20',
        protection: ProtectionLevel.biometric,
      );
      vault.failNext(VaultOperation.read, const VaultKeyInvalidated());
      await expectLater(
        mfa.currentCode(a.id),
        throwsA(const VaultKeyInvalidated()),
      );
    });
  });

  group('rename, wipe, watch, dispose', () {
    test(
      'rename changes only the given fields; blank issuer clears it',
      () async {
        final mfa = await client();
        final a = await mfa.enrollFromUri(
          'otpauth://totp/Ex:alice?secret=$_secret20',
        );
        expect(
          (await mfa.rename(a.id, accountName: ' alicia ')).accountName,
          'alicia',
        );
        expect((await mfa.rename(a.id, issuer: 'New')).issuer, 'New');
        final cleared = await mfa.rename(a.id, issuer: '');
        expect((cleared.issuer, cleared.accountName), (null, 'alicia'));
        await expectLater(
          mfa.rename(a.id, accountName: ' '),
          throwsA(isA<OtpConfigException>()),
        );
      },
    );

    test(
      'watchAccounts emits the current list, then after every change',
      () async {
        final mfa = await client();
        final events = <int>[];
        final sub = mfa.watchAccounts().listen((l) => events.add(l.length));
        await pumpEventQueue();
        final a = await mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20');
        await mfa.rename(a.id, accountName: 'b');
        await mfa.enrollFromUri('otpauth://hotp/c?secret=$_secret20&counter=0');
        await mfa.wipeAll();
        await pumpEventQueue();
        await sub.cancel();
        expect(events, [0, 1, 1, 2, 0]);
      },
    );

    test('wipeAll removes all secrets and the index', () async {
      final mfa = await client();
      await mfa.enrollFromUri('otpauth://totp/a?secret=$_secret20');
      await mfa.wipeAll();
      expect(await vault.keys(), isEmpty);
    });

    test('capabilities come from the vault', () async {
      final mfa = await client();
      expect(await mfa.capabilities, InMemoryMfaPlatform.allCapabilities);
    });

    test('a disposed client refuses further use', () async {
      final mfa = await client();
      await mfa.dispose();
      await mfa.dispose();
      expect(() => mfa.accounts(), throwsStateError);
      expect(() => mfa.capabilities, throwsStateError);
    });
  });

  group('logging policy (FR-FAC-04)', () {
    test('logs never contain secrets, codes, URIs or account names', () async {
      final mfa = await client();
      final a = await mfa.enrollFromUri(
        'otpauth://totp/Example:alice?secret=$_secret20',
      );
      final code = await mfa.currentCode(a.id);
      await mfa.rename(a.id, accountName: 'renamed');
      await mfa.remove(a.id);
      await mfa.wipeAll();
      final all = logger.messages.join('\n');
      expect(logger.messages, isNotEmpty);
      for (final forbidden in [
        _secret20,
        '1234567890',
        code.value,
        'otpauth',
        'alice',
        'Example',
        'renamed',
      ]) {
        expect(all, isNot(contains(forbidden)), reason: 'logged "$forbidden"');
      }
    });
  });
}
