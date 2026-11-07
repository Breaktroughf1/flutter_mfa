import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa/src/client/backup_import.dart';
import 'package:flutter_test/flutter_test.dart';

OtpAccount _account(String id, String name, {String? issuer = 'Example'}) =>
    OtpAccount(
      id: id,
      type: OtpType.totp,
      issuer: issuer,
      accountName: name,
      algorithm: OtpAlgorithm.sha1,
      digits: 6,
      period: const Duration(seconds: 30),
      protection: ProtectionLevel.standard,
      createdAt: DateTime.utc(2026, 11, 6),
    );

void main() {
  var counter = 0;
  String newId() =>
      '00000000-0000-4000-8000-${(100 + ++counter).toString().padLeft(12, '0')}';
  setUp(() => counter = 0);

  List<String> ids(List<OtpAccount> accounts) => [
    for (final a in accounts) a.id,
  ];

  test('accounts not on the device are added with their ids', () {
    final plan = planImport(
      [_account('00000000-0000-4000-8000-000000000001', 'alice')],
      [
        _account('00000000-0000-4000-8000-000000000002', 'bob'),
        _account('00000000-0000-4000-8000-000000000003', 'carol'),
      ],
      DuplicateStrategy.skip,
      newId,
    );
    expect(
      [for (final (a, i) in plan.add) (a.id, i)],
      [
        ('00000000-0000-4000-8000-000000000002', 0),
        ('00000000-0000-4000-8000-000000000003', 1),
      ],
    );
    expect(plan.remove, isEmpty);
    expect(ids(plan.report.added), [
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000003',
    ]);
    expect(plan.report.replaced, isEmpty);
    expect(plan.report.skipped, isEmpty);
  });

  group('a duplicate is the same id, or the same type, issuer and name', () {
    final current = [_account('00000000-0000-4000-8000-000000000001', 'alice')];
    for (final incoming in [
      _account('00000000-0000-4000-8000-000000000001', 'renamed'),
      _account('00000000-0000-4000-8000-000000000004', 'alice'),
    ]) {
      test('skip keeps the existing account (${incoming.accountName})', () {
        final plan = planImport(
          current,
          [incoming],
          DuplicateStrategy.skip,
          newId,
        );
        expect(plan.add, isEmpty);
        expect(plan.remove, isEmpty);
        expect(plan.report.skipped, [incoming]);
      });

      test('replace removes it and stores the backup under a new id '
          '(${incoming.accountName})', () {
        final plan = planImport(
          current,
          [incoming],
          DuplicateStrategy.replace,
          newId,
        );
        final (stored, index) = plan.add.single;
        expect(stored.id, '00000000-0000-4000-8000-000000000101');
        expect(index, 0);
        expect(stored.accountName, incoming.accountName);
        expect(stored.createdAt, incoming.createdAt);
        expect(plan.remove, {'00000000-0000-4000-8000-000000000001'});
        expect(ids(plan.report.replaced), [
          '00000000-0000-4000-8000-000000000101',
        ]);
        expect(plan.report.added, isEmpty);
      });
    }

    test('keepBoth keeps both, with a new id only when the id is taken', () {
      final plan = planImport(
        current,
        [
          _account('00000000-0000-4000-8000-000000000001', 'renamed'),
          _account('00000000-0000-4000-8000-000000000004', 'alice'),
        ],
        DuplicateStrategy.keepBoth,
        newId,
      );
      expect(ids([for (final (a, _) in plan.add) a]), [
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000004',
      ]);
      expect(plan.remove, isEmpty);
      expect(ids(plan.report.added), [
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000004',
      ]);
    });
  });

  test('a different issuer or a missing issuer is a different account', () {
    final plan = planImport(
      [_account('00000000-0000-4000-8000-000000000001', 'alice')],
      [
        _account(
          '00000000-0000-4000-8000-000000000002',
          'alice',
          issuer: 'Other',
        ),
        _account('00000000-0000-4000-8000-000000000003', 'alice', issuer: null),
      ],
      DuplicateStrategy.skip,
      newId,
    );
    expect(ids(plan.report.added), [
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000003',
    ]);
  });

  test('duplicates inside the backup follow the same strategy', () {
    final twice = [
      _account('00000000-0000-4000-8000-000000000002', 'bob'),
      _account('00000000-0000-4000-8000-000000000002', 'bob'),
    ];
    final skip = planImport([], twice, DuplicateStrategy.skip, newId);
    expect(ids(skip.report.added), ['00000000-0000-4000-8000-000000000002']);
    expect(skip.report.skipped, hasLength(1));

    final replace = planImport([], twice, DuplicateStrategy.replace, newId);
    expect(
      [for (final (a, i) in replace.add) (a.id, i)],
      [('00000000-0000-4000-8000-000000000101', 1)],
    );
    expect(replace.remove, isEmpty, reason: 'b was never stored');
    expect(replace.report.added, isEmpty);
    expect(ids(replace.report.replaced), [
      '00000000-0000-4000-8000-000000000101',
    ]);

    final both = planImport([], twice, DuplicateStrategy.keepBoth, newId);
    expect(ids(both.report.added), [
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000102',
    ]);
  });

  test('replacing an account that replaced another keeps one copy', () {
    final plan = planImport(
      [_account('00000000-0000-4000-8000-000000000001', 'alice')],
      [
        _account('00000000-0000-4000-8000-000000000001', 'alice'),
        _account('00000000-0000-4000-8000-000000000005', 'alice'),
      ],
      DuplicateStrategy.replace,
      newId,
    );
    expect(ids([for (final (a, _) in plan.add) a]), [
      '00000000-0000-4000-8000-000000000102',
    ]);
    expect(plan.remove, {'00000000-0000-4000-8000-000000000001'});
    expect(ids(plan.report.replaced), ['00000000-0000-4000-8000-000000000102']);
  });

  test('the report never shows secrets', () {
    final plan = planImport(
      [],
      [_account('00000000-0000-4000-8000-000000000002', 'bob')],
      DuplicateStrategy.skip,
      newId,
    );
    expect(
      plan.report.toString(),
      'ImportReport(added: 1, replaced: 0, skipped: 0)',
    );
  });
}
