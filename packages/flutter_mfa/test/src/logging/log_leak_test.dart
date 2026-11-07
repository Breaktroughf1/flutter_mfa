// FR-FAC-04: nothing secret reaches the logger, across the whole journey.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _totpSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const _hotpSecret = 'JBSWY3DPEHPK3PXP';
const _passphrase = 'correct horse battery staple';

final class _AllLevels implements MfaLogger {
  final messages = <String>[];
  @override
  void log(MfaLogLevel level, String message) => messages.add(message);
}

final class _Check implements DeviceIntegrityCheck {
  @override
  Future<IntegrityReport> run() async =>
      IntegrityReport(verdict: IntegrityVerdict.suspicious, signals: ['test']);
}

String _hex(String base32) => OtpSecret.fromBase32(
  base32,
).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test(
    'the full journey logs no secret, code, passphrase or URI (FR-FAC-04)',
    () async {
      final logger = _AllLevels();
      final vault = InMemoryMfaPlatform();
      MfaPlatform.instance = vault;
      final clock = FakeClock(DateTime.utc(2026, 11, 7, 12));
      final codes = <String>{};
      final mfa = await MfaClient.create(
        options: MfaClientOptions(
          clock: clock,
          logger: logger,
          integrityCheck: _Check(),
        ),
      );

      final uri =
          'otpauth://totp/Example:alice?secret=$_totpSecret&issuer=Example';
      final totp = await mfa.enrollFromUri(uri);
      final hotp = await mfa.enrollManual(
        secretBase32: _hotpSecret,
        accountName: 'bob',
        issuer: 'Counter',
        type: OtpType.hotp,
        protection: ProtectionLevel.biometric,
      );
      codes.add((await mfa.currentCode(totp.id)).value);
      codes.add((await mfa.currentCode(hotp.id)).value);
      codes.addAll(
        await mfa.codeStream(totp.id).take(2).map((c) => c.value).toList(),
      );
      await mfa.copyCode(totp.id);
      codes.add(vault.clipboard!.$1);
      await mfa.rename(totp.id, accountName: 'alice (work)');
      await mfa.setScreenCaptureProtection(true);
      await mfa.checkIntegrity();

      final backup = await mfa.exportEncrypted(_passphrase);
      await expectLater(
        mfa.importEncrypted(backup, 'a wrong but long passphrase'),
        throwsA(isA<BackupDecryptFailed>()),
      );
      await mfa.importEncrypted(
        backup,
        _passphrase,
        onDuplicate: DuplicateStrategy.keepBoth,
      );
      await expectLater(
        mfa.exportEncrypted('password1234'),
        throwsA(isA<BackupWeakPassphrase>()),
      );
      await mfa.remove(totp.id);
      await mfa.wipeAll();
      await mfa.dispose();

      final forbidden = <String>{
        _totpSecret,
        _hotpSecret,
        _totpSecret.toLowerCase(),
        _hotpSecret.toLowerCase(),
        _hex(_totpSecret),
        _hex(_hotpSecret),
        _passphrase,
        'password1234',
        'otpauth',
      };
      // Account ids are random UUIDs; blank them before looking for codes,
      // so a code that happens to occur inside an id cannot fail the test.
      final uuid = RegExp(
        '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      );
      expect(logger.messages, isNotEmpty);
      for (final message in logger.messages) {
        final withoutIds = message.replaceAll(uuid, '<id>');
        // Compared without printing the value on failure.
        for (final value in forbidden) {
          expect(
            message.contains(value),
            isFalse,
            reason: 'a log message contains a secret or the passphrase',
          );
        }
        for (final code in codes) {
          expect(
            withoutIds.contains(code),
            isFalse,
            reason: 'a log message contains a code',
          );
        }
      }
      expect(
        logger.messages,
        containsAll([
          'integrity suspicious',
          'screen capture protection on',
          'vault wiped',
        ]),
      );
    },
  );
}
