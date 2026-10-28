import 'dart:math';

import 'env_stub.dart' if (dart.library.io) 'env_io.dart';

/// Number of property/fuzz iterations: `FMFA_FUZZ_RUNS` (CI sets 10k on PRs,
/// 200k nightly), default 10000 (05_TEST_PLAN §1). Browser runs use 1000.
int fuzzRuns() {
  final fromEnv = int.tryParse(readEnv('FMFA_FUZZ_RUNS') ?? '');
  if (fromEnv != null) return fromEnv;
  return identical(0, 0.0) ? 1000 : 10000; // true only when compiled to JS
}

/// Deterministic generator for reproducible fuzz failures. Tests only;
/// library code must use `Random.secure()`.
Random fuzzRandom([int seed = 0x5eed]) => Random(seed);
