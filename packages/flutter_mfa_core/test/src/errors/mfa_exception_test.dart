import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  group('MfaException hierarchy', () {
    final all = <MfaException>[
      const OtpConfigException(field: 'digits', reason: 'must be 6, 7 or 8'),
      const OtpAuthUriException(field: 'secret', reason: 'missing'),
      const VerificationRateLimited(retryAfter: Duration(seconds: 30)),
      const VaultNotFound(),
      const VaultUserCancelled(),
      const VaultKeyInvalidated(),
      const VaultHardwareUnavailable(
        HardwareUnavailableReason.secureEnclaveUnavailable,
      ),
      const VaultUnavailable(VaultUnavailableReason.insecureContext),
      const VaultCorrupted(),
      const VaultUnknown('E42'),
      const BackupDecryptFailed(),
      const BackupUnsupportedVersion(7),
      const BackupWeakPassphrase(PassphraseCheck.tooShort),
    ];

    test('every error is an Exception (not an Error)', () {
      for (final e in all) {
        expect(e, isA<Exception>());
      }
    });

    test('a switch over the sealed root is exhaustive', () {
      String kind(MfaException e) => switch (e) {
        OtpConfigException() => 'config',
        OtpAuthUriException() => 'uri',
        VerificationRateLimited() => 'limited',
        VaultException() => 'vault',
        BackupException() => 'backup',
      };
      expect(all.map(kind).toSet(), {
        'config',
        'uri',
        'limited',
        'vault',
        'backup',
      });
    });

    test('a switch over VaultException is exhaustive (FR-VLT-07)', () {
      String name(VaultException e) => switch (e) {
        VaultNotFound() => 'NotFound',
        VaultUserCancelled() => 'UserCancelled',
        VaultKeyInvalidated() => 'KeyInvalidated',
        VaultHardwareUnavailable() => 'HardwareUnavailable',
        VaultUnavailable() => 'VaultUnavailable',
        VaultCorrupted() => 'Corrupted',
        VaultUnknown() => 'Unknown',
      };
      expect(all.whereType<VaultException>().map(name), hasLength(7));
    });

    test('a switch over BackupException is exhaustive', () {
      String name(BackupException e) => switch (e) {
        BackupDecryptFailed() => 'decrypt',
        BackupUnsupportedVersion() => 'version',
        BackupWeakPassphrase() => 'weak',
      };
      expect(all.whereType<BackupException>().map(name), hasLength(3));
    });

    test('toString names the type and carries field + reason only', () {
      expect(
        const OtpConfigException(
          field: 'digits',
          reason: 'must be 6, 7 or 8',
        ).toString(),
        'OtpConfigException(field: digits, reason: must be 6, 7 or 8)',
      );
      expect(
        const VerificationRateLimited(
          retryAfter: Duration(seconds: 30),
        ).toString(),
        'VerificationRateLimited(retryAfter: 30s)',
      );
      expect(
        const VaultUnavailable(
          VaultUnavailableReason.insecureContext,
        ).toString(),
        'VaultUnavailable(reason: insecureContext)',
      );
      expect(const VaultUnknown('E42').toString(), 'VaultUnknown(code: E42)');
      expect(
        const BackupUnsupportedVersion(7).toString(),
        'BackupUnsupportedVersion(version: 7)',
      );
    });

    test('every toString starts with the exact type name', () {
      final names = {
        for (final e in all) e.toString().split('(').first,
      };
      expect(names, {
        'OtpConfigException',
        'OtpAuthUriException',
        'VerificationRateLimited',
        'VaultNotFound',
        'VaultUserCancelled',
        'VaultKeyInvalidated',
        'VaultHardwareUnavailable',
        'VaultUnavailable',
        'VaultCorrupted',
        'VaultUnknown',
        'BackupDecryptFailed',
        'BackupUnsupportedVersion',
        'BackupWeakPassphrase',
      });
      expect(
        const OtpAuthUriException(
          field: 'secret',
          reason: 'missing',
        ).toString(),
        'OtpAuthUriException(field: secret, reason: missing)',
      );
      expect(
        const BackupWeakPassphrase(PassphraseCheck.tooCommon).toString(),
        'BackupWeakPassphrase(check: tooCommon)',
      );
    });

    test('sub-second retryAfter is rendered in milliseconds', () {
      expect(
        const VerificationRateLimited(
          retryAfter: Duration(milliseconds: 1500),
        ).toString(),
        'VerificationRateLimited(retryAfter: 1500ms)',
      );
    });

    test('each error equals only itself among all error kinds', () {
      for (var i = 0; i < all.length; i++) {
        for (var j = 0; j < all.length; j++) {
          expect(all[i] == all[j], i == j, reason: '$i vs $j');
        }
      }
    });

    test('value equality for identical errors', () {
      expect(
        const OtpConfigException(field: 'a', reason: 'b'),
        const OtpConfigException(field: 'a', reason: 'b'),
      );
      expect(
        const OtpConfigException(field: 'a', reason: 'b'),
        isNot(const OtpConfigException(field: 'a', reason: 'c')),
      );
      expect(
        const VaultHardwareUnavailable(
          HardwareUnavailableReason.strongBoxUnavailable,
        ).hashCode,
        const VaultHardwareUnavailable(
          HardwareUnavailableReason.strongBoxUnavailable,
        ).hashCode,
      );
      expect(const VaultNotFound(), const VaultNotFound());
      expect(const VaultNotFound(), isNot(const VaultCorrupted()));
    });
  });

  group('OtpAuthUriException', () {
    test('is a FormatException so URI fuzzing only ever sees '
        'FormatException (FR-URI-01 AC5)', () {
      const e = OtpAuthUriException(field: 'counter', reason: 'required');
      expect(e, isA<FormatException>());
      expect(e.message, 'counter: required');
      expect(e.source, isNull, reason: 'the URI may contain the secret');
      expect(e.offset, isNull);
    });
  });

  group('VaultKeyInvalidated', () {
    test('explains the recovery path in its toString', () {
      expect(
        const VaultKeyInvalidated().toString(),
        contains('re-enrol or restore from backup'),
      );
    });
  });
}
