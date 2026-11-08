// The real codec runs here (600 000 PBKDF2 iterations per call), so the
// backup is made once and imported into a fresh vault by each test.
@Timeout(Duration(minutes: 2))
library;

import 'dart:typed_data';

import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret20 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // RFC 4226 test secret
const _passphrase = 'correct horse battery staple';

final class _CapturingLogger implements MfaLogger {
  final messages = <String>[];
  @override
  void log(MfaLogLevel level, String message) => messages.add(message);
}

void main() {
  final clock = FakeClock(
    DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
  );
  late _CapturingLogger logger;
  late InMemoryMfaPlatform source;
  late Uint8List backup;
  late List<OtpAccount> backedUp;
  late String totpCode;

  Future<MfaClient> client(InMemoryMfaPlatform vault) {
    MfaPlatform.instance = vault;
    return MfaClient.create(
      options: MfaClientOptions(clock: clock, logger: logger),
    );
  }

  setUpAll(() async {
    logger = _CapturingLogger();
    source = InMemoryMfaPlatform();
    final mfa = await client(source);
    final totp = await mfa.enrollFromUri(
      'otpauth://totp/Example:alice?secret=$_secret20&issuer=Example',
    );
    await mfa.enrollManual(
      secretBase32: _secret20,
      accountName: 'bob',
      issuer: 'Counter',
      type: OtpType.hotp,
      counter: 5,
      protection: ProtectionLevel.biometric,
    );
    totpCode = (await mfa.currentCode(totp.id)).value;
    backedUp = await mfa.accounts();
    source.prompts.clear();
    backup = await mfa.exportEncrypted(_passphrase);
    await mfa.dispose();
  });

  setUp(() => logger = _CapturingLogger());

  test('exporting reads protected secrets after a prompt, once each', () {
    expect(source.prompts, hasLength(1));
    expect(backup.sublist(0, 4), 'FMFA'.codeUnits);
  });

  test('a backup restores every account with its id, protection, counter and '
      'codes on another device (FR-BAK-03)', () async {
    final target = InMemoryMfaPlatform();
    final mfa = await client(target);
    final report = await mfa.importEncrypted(backup, _passphrase);
    expect(report.added, backedUp);
    expect(report.replaced, isEmpty);
    expect(report.skipped, isEmpty);
    expect(await mfa.accounts(), backedUp);
    expect(
      target.levelOf('acct_${backedUp[1].id}'),
      ProtectionLevel.biometric,
    );
    expect((await mfa.currentCode(backedUp[0].id)).value, totpCode);
    final hotp = await mfa.currentCode(backedUp[1].id);
    expect(hotp.step, 5, reason: 'the HOTP counter is restored');
    expect(logger.messages.join(), isNot(contains(_secret20)));
    expect(logger.messages.join(), isNot(contains(_passphrase)));
  });

  test(
    'a wrong passphrase or a modified byte changes nothing (FR-BAK-03 AC1)',
    () async {
      final target = InMemoryMfaPlatform();
      final mfa = await client(target);
      final existing = await mfa.enrollManual(
        secretBase32: _secret20,
        accountName: 'carol',
      );
      final keys = await target.keys();
      await expectLater(
        mfa.importEncrypted(backup, 'a different long passphrase'),
        throwsA(isA<BackupDecryptFailed>()),
      );
      final tampered = Uint8List.fromList(backup);
      tampered[60] ^= 1;
      await expectLater(
        mfa.importEncrypted(tampered, _passphrase),
        throwsA(isA<BackupDecryptFailed>()),
      );
      expect(await mfa.accounts(), [existing]);
      expect(await target.keys(), keys);
    },
  );

  test(
    'a failure while storing leaves the vault as it was (no partial import)',
    () async {
      final target = InMemoryMfaPlatform();
      final mfa = await client(target);
      final existing = await mfa.enrollManual(
        secretBase32: _secret20,
        accountName: 'carol',
      );
      final keys = await target.keys();
      target.failNext(
        VaultOperation.write,
        const VaultUnavailable(VaultUnavailableReason.storageUnavailable),
        key: 'acct_${backedUp[1].id}',
      );
      await expectLater(
        mfa.importEncrypted(backup, _passphrase),
        throwsA(isA<VaultUnavailable>()),
      );
      expect(await mfa.accounts(), [existing]);
      expect(await target.keys(), keys, reason: 'written secrets deleted');
    },
  );

  test(
    'an account this device cannot protect as before fails the whole import',
    () async {
      final target = InMemoryMfaPlatform(
        capabilities: InMemoryMfaPlatform.allCapabilities.copyWithLevels(),
      );
      final mfa = await client(target);
      await expectLater(
        mfa.importEncrypted(backup, _passphrase),
        throwsA(isA<VaultHardwareUnavailable>()),
      );
      expect(await mfa.accounts(), isEmpty);
      expect(await target.keys(), isEmpty);
    },
  );

  group('duplicates (FR-BAK-03 AC2)', () {
    late InMemoryMfaPlatform target;
    late MfaClient mfa;
    late OtpAccount existing;

    setUp(() async {
      target = InMemoryMfaPlatform();
      mfa = await client(target);
      final first = await mfa.importEncrypted(backup, _passphrase);
      existing = first.added.first;
      await mfa.rename(existing.id, accountName: 'alice (renamed)');
    });

    test('skip, the default, keeps what is on the device', () async {
      final before = await mfa.accounts();
      final report = await mfa.importEncrypted(backup, _passphrase);
      expect(report.added, isEmpty);
      expect(report.skipped, backedUp);
      expect(await mfa.accounts(), before);
    });

    test('replace swaps in the backed-up accounts under new ids', () async {
      final report = await mfa.importEncrypted(
        backup,
        _passphrase,
        onDuplicate: DuplicateStrategy.replace,
      );
      expect(report.replaced, hasLength(2));
      final accounts = await mfa.accounts();
      expect(accounts, report.replaced);
      expect(accounts.first.accountName, 'alice');
      expect(accounts.map((a) => a.id), isNot(contains(existing.id)));
      expect(await target.keys(), hasLength(3), reason: 'old secrets gone');
      expect((await mfa.currentCode(accounts.first.id)).value, totpCode);
    });

    test(
      'a failed clean-up after the commit still reports the import',
      () async {
        target.failNext(
          VaultOperation.delete,
          const VaultUnavailable(VaultUnavailableReason.storageUnavailable),
          key: 'acct_${existing.id}',
        );
        final report = await mfa.importEncrypted(
          backup,
          _passphrase,
          onDuplicate: DuplicateStrategy.replace,
        );
        expect(report.replaced, hasLength(2));
        expect(
          await target.keys(),
          contains('acct_${existing.id}'),
          reason: 'left as an orphan for the next sweep',
        );
        final next = await client(target);
        expect(await next.accounts(), report.replaced);
        expect(
          await target.keys(),
          isNot(contains('acct_${existing.id}')),
          reason: 'swept on the next load',
        );
      },
    );

    test('keepBoth stores a second copy with new ids', () async {
      final report = await mfa.importEncrypted(
        backup,
        _passphrase,
        onDuplicate: DuplicateStrategy.keepBoth,
      );
      expect(report.added, hasLength(2));
      expect(await mfa.accounts(), hasLength(4));
    });
  });

  group('export', () {
    test(
      'a weak passphrase is refused before any secret is read',
      () async {
        final mfa = await client(source);
        source.prompts.clear();
        await expectLater(
          mfa.exportEncrypted('password1234'),
          throwsA(
            isA<BackupWeakPassphrase>().having(
              (e) => e.check,
              'check',
              PassphraseCheck.tooCommon,
            ),
          ),
        );
        expect(source.prompts, isEmpty);
      },
    );

    test('only the chosen accounts, and unknown ids fail', () async {
      final mfa = await client(source);
      await expectLater(
        mfa.exportEncrypted(_passphrase, accountIds: ['missing']),
        throwsA(isA<VaultNotFound>()),
      );
      final one = await mfa.exportEncrypted(
        _passphrase,
        accountIds: [backedUp[0].id, backedUp[0].id],
      );
      final entries = await const BackupCodec().decrypt(one, _passphrase);
      expect([for (final e in entries) e.account], [backedUp[0]]);
      expect(logger.messages, contains('exported 1 accounts'));
    });

    test('a cancelled prompt stops the export', () async {
      final mfa = await client(source);
      source.onBiometricPrompt = (_) => false;
      addTearDown(() => source.onBiometricPrompt = (_) => true);
      await expectLater(
        mfa.exportEncrypted(_passphrase),
        throwsA(isA<VaultUserCancelled>()),
      );
    });

    test('a disposed client refuses both', () async {
      final mfa = await client(source);
      await mfa.dispose();
      expect(() => mfa.exportEncrypted(_passphrase), throwsStateError);
      expect(
        () => mfa.importEncrypted(backup, _passphrase),
        throwsStateError,
      );
    });
  });
}

extension on VaultCapabilities {
  VaultCapabilities copyWithLevels() => VaultCapabilities(
    hardwareBacked: hardwareBacked,
    strongBox: strongBox,
    secureEnclave: secureEnclave,
    biometricsEnrolled: biometricsEnrolled,
    secureContext: secureContext,
    persistentStorage: persistentStorage,
    screenCaptureProtection: screenCaptureProtection,
    supportedLevels: const {ProtectionLevel.standard},
  );
}
