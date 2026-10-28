import 'dart:math';

/// Deterministic, **insecure** pseudo-random generator for reproducible
/// tests. Exported only from `testing.dart`; never use it for secrets or ids
/// in production (library code uses `Random.secure()`).
final class SeededRandom implements Random {
  /// Creates a generator for [seed].
  SeededRandom(int seed) : _inner = Random(seed);

  final Random _inner;

  @override
  bool nextBool() => _inner.nextBool();

  @override
  double nextDouble() => _inner.nextDouble();

  @override
  int nextInt(int max) => _inner.nextInt(max);
}
