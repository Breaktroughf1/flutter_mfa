import 'dart:async';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  group('AsyncMutex', () {
    test('runs critical sections one at a time, in call order', () async {
      final mutex = AsyncMutex();
      final log = <String>[];
      Future<void> section(String name) => mutex.protect(() async {
        log.add('$name:start');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        log.add('$name:end');
      });

      await Future.wait([section('a'), section('b'), section('c')]);

      expect(log, [
        'a:start',
        'a:end',
        'b:start',
        'b:end',
        'c:start',
        'c:end',
      ]);
    });

    test('returns the value of the critical section', () async {
      final mutex = AsyncMutex();
      expect(await mutex.protect(() async => 42), 42);
    });

    test(
      'a throwing section propagates its error and releases the lock',
      () async {
        final mutex = AsyncMutex();
        await expectLater(
          mutex.protect<void>(() async => throw StateError('boom')),
          throwsStateError,
        );
        expect(await mutex.protect(() async => 'next'), 'next');
      },
    );

    test('a synchronously throwing section also releases the lock', () async {
      final mutex = AsyncMutex();
      await expectLater(
        mutex.protect<void>(() => throw StateError('sync')),
        throwsStateError,
      );
      expect(await mutex.protect(() async => 1), 1);
    });

    test('isLocked reflects whether a section is running or queued', () async {
      final mutex = AsyncMutex();
      expect(mutex.isLocked, isFalse);
      final gate = Completer<void>();
      final running = mutex.protect(() => gate.future);
      expect(mutex.isLocked, isTrue);
      gate.complete();
      await running;
      expect(mutex.isLocked, isFalse);
    });

    test('concurrent read-modify-write does not lose updates', () async {
      final mutex = AsyncMutex();
      var counter = 0;
      await Future.wait([
        for (var i = 0; i < 100; i++)
          mutex.protect(() async {
            final read = counter;
            await Future<void>.delayed(Duration.zero);
            counter = read + 1;
          }),
      ]);
      expect(counter, 100);
    });
  });
}
