@TestOn('vm')
library;

import 'package:flutter_mfa_core/testing.dart';
import 'package:test/test.dart';

import '../example/main.dart' as example;

void main() {
  test(
    'the server example enrols, accepts once, rejects replay, then throttles',
    () async {
      final log = await example.runDemo(
        clock: FakeClock(DateTime.utc(2026, 10, 28, 12)),
      );
      expect(log, [
        'enrolment URI ready (otpauth, 0 warnings)',
        'accepted',
        'rejected: replayed',
        'rate limited: retry after 1s',
      ]);
    },
  );

  test('main runs to completion', () async {
    await example.main();
  });
}
