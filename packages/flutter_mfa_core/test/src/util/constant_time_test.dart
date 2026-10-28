import 'dart:collection';

import 'package:flutter_mfa_core/src/util/constant_time.dart';
import 'package:test/test.dart';

void main() {
  group('constantTimeEquals', () {
    test('equal byte lists compare equal', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('empty lists compare equal', () {
      expect(constantTimeEquals(const [], const []), isTrue);
    });

    test('a difference at any position is detected', () {
      for (var i = 0; i < 6; i++) {
        final b = [0, 0, 0, 0, 0, 0]..[i] = 1;
        expect(constantTimeEquals(const [0, 0, 0, 0, 0, 0], b), isFalse);
      }
    });

    test('different lengths compare unequal, including a prefix', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
      expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
      expect(constantTimeEquals(const [], [0]), isFalse);
    });

    test('only the low 8 bits of each element are compared', () {
      // Inputs are bytes; values above 255 must not create false negatives
      // through sign or overflow tricks.
      expect(constantTimeEquals([256], [0]), isTrue);
      expect(constantTimeEquals([257], [0]), isFalse);
    });

    test('iterates the full length regardless of mismatch position '
        '(FR-VER-04)', () {
      final first = _CountingList(List<int>.filled(32, 7)..[0] = 8);
      final last = _CountingList(List<int>.filled(32, 7)..[31] = 8);
      final ref = List<int>.filled(32, 7);
      expect(constantTimeEquals(first, ref), isFalse);
      expect(constantTimeEquals(last, ref), isFalse);
      expect(first.reads, 32);
      expect(last.reads, 32);
    });

    test('reads the longer input in full when lengths differ', () {
      final longer = _CountingList(List<int>.filled(10, 1));
      expect(constantTimeEquals(longer, List<int>.filled(4, 1)), isFalse);
      expect(longer.reads, 10);
    });
  });

  group('constantTimeStringEquals', () {
    test('compares code units without early exit', () {
      expect(constantTimeStringEquals('123456', '123456'), isTrue);
      expect(constantTimeStringEquals('123456', '123457'), isFalse);
      expect(constantTimeStringEquals('123456', '12345'), isFalse);
      expect(constantTimeStringEquals('', ''), isTrue);
    });

    test('distinguishes non-ASCII code units', () {
      expect(constantTimeStringEquals('٣', '3'), isFalse);
      expect(constantTimeStringEquals('ā', 'ā'), isTrue);
    });
  });
}

/// A list that counts element reads, to prove the comparison does not stop early.
final class _CountingList extends ListBase<int> {
  _CountingList(this._inner);

  final List<int> _inner;
  int reads = 0;

  @override
  int get length => _inner.length;

  @override
  set length(int value) => throw UnsupportedError('fixed length');

  @override
  int operator [](int index) {
    reads++;
    return _inner[index];
  }

  @override
  void operator []=(int index, int value) => _inner[index] = value;
}
