import 'dart:math';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  final created = DateTime.utc(2026, 10, 28, 9, 30);
  OtpAccount account({
    String? issuer = 'Example',
    OtpType type = OtpType.totp,
    int? counter,
  }) => OtpAccount(
    id: '3f2b8c1e-4d5a-4b6c-8d7e-9f0a1b2c3d4e',
    type: type,
    issuer: issuer,
    accountName: 'alice@example.com',
    counter: counter,
    createdAt: created,
  );

  group('OtpAccount', () {
    test('defaults: SHA-1, 6 digits, 30 s, standard protection', () {
      final a = account();
      expect(a.algorithm, OtpAlgorithm.sha1);
      expect(a.digits, 6);
      expect(a.period, const Duration(seconds: 30));
      expect(a.protection, ProtectionLevel.standard);
      expect(a.lastUsedStep, isNull);
    });

    test('displayName is "Issuer (account)" or just the account', () {
      expect(account().displayName, 'Example (alice@example.com)');
      expect(account(issuer: null).displayName, 'alice@example.com');
    });

    test('totpConfig / hotpConfig reflect the type', () {
      expect(account().totpConfig, const TotpConfig());
      expect(account().hotpConfig, isNull);
      final h = account(type: OtpType.hotp, counter: 3);
      expect(h.hotpConfig, const HotpConfig());
      expect(h.totpConfig, isNull);
    });

    test(
      'copyWith replaces only the given fields and can clear the issuer',
      () {
        final a = account();
        final b = a.copyWith(
          accountName: 'bob',
          lastUsedStep: 9,
          protection: ProtectionLevel.biometric,
        );
        expect(b.accountName, 'bob');
        expect(b.lastUsedStep, 9);
        expect(b.protection, ProtectionLevel.biometric);
        expect(b.id, a.id);
        expect(b.issuer, 'Example');
        expect(a.copyWith(issuer: () => null).issuer, isNull);
        expect(a.copyWith(counter: () => 4).counter, 4);
        expect(a.copyWith(), a);
      },
    );

    test('value equality and hashCode', () {
      expect(account(), account());
      expect(account().hashCode, account().hashCode);
      expect(account(), isNot(account(issuer: 'Other')));
    });

    test('toString shows non-secret metadata only', () {
      expect(
        account().toString(),
        'OtpAccount(3f2b8c1e-4d5a-4b6c-8d7e-9f0a1b2c3d4e, totp, Example (alice@example.com), standard)',
      );
    });
  });

  group('OtpAccount JSON (single serialisation for the vault index)', () {
    test('round-trips every field', () {
      final a = OtpAccount(
        id: OtpAccount.generateId(),
        type: OtpType.hotp,
        issuer: 'ACME',
        accountName: 'bob',
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        period: const Duration(seconds: 60),
        counter: 42,
        lastUsedStep: 7,
        protection: ProtectionLevel.hardwareBound,
        createdAt: created,
      );
      expect(OtpAccount.fromJson(a.toJson()), a);
    });

    test('has a stable, versioned shape', () {
      expect(account().toJson(), {
        'v': 1,
        'id': '3f2b8c1e-4d5a-4b6c-8d7e-9f0a1b2c3d4e',
        'type': 'totp',
        'issuer': 'Example',
        'accountName': 'alice@example.com',
        'algorithm': 'sha1',
        'digits': 6,
        'periodSeconds': 30,
        'counter': null,
        'lastUsedStep': null,
        'protection': 'standard',
        'createdAt': '2026-10-28T09:30:00.000Z',
      });
    });

    test('rejects malformed or unknown data with FormatException', () {
      final good = account().toJson();
      final bad = <Map<String, Object?>>[
        {...good, 'v': 2},
        {...good, 'id': 'not-a-uuid'},
        {...good, 'type': 'motp'},
        {...good, 'issuer': 5},
        {...good, 'accountName': ''},
        {...good, 'algorithm': 'md5'},
        {...good, 'digits': 9},
        {...good, 'periodSeconds': 0},
        {...good, 'counter': -1},
        {...good, 'lastUsedStep': 'x'},
        {...good, 'protection': 'none'},
        {...good, 'createdAt': 'yesterday'},
        {...good}..remove('createdAt'),
        {...good, 'type': 'hotp', 'counter': null},
      ];
      for (final json in bad) {
        expect(
          () => OtpAccount.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('the FormatException never includes the input', () {
      try {
        OtpAccount.fromJson({...account().toJson(), 'digits': 9});
        fail('expected FormatException');
      } on FormatException catch (e) {
        expect(e.source, isNull);
        expect(e.toString(), isNot(contains('alice')));
      }
    });
  });

  group('OtpAccount.generateId', () {
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('produces RFC 9562 version-4 UUIDs', () {
      for (var i = 0; i < 200; i++) {
        expect(OtpAccount.generateId(), matches(uuidV4));
      }
    });

    test('is random (Random.secure by default) and injectable for tests', () {
      expect(OtpAccount.generateId(), isNot(OtpAccount.generateId()));
      expect(
        OtpAccount.generateId(random: Random(1)),
        OtpAccount.generateId(random: Random(1)),
      );
    });
  });

  test('ProtectionLevel lists the three levels in increasing strength', () {
    expect(ProtectionLevel.values, [
      ProtectionLevel.standard,
      ProtectionLevel.biometric,
      ProtectionLevel.hardwareBound,
    ]);
  });
}
