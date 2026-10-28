import 'dart:io';
import 'dart:math';

/// Number of property/fuzz iterations: `FMFA_FUZZ_RUNS` (CI sets 10k on PRs,
/// 200k nightly), default 10000 (05_TEST_PLAN §1).
int fuzzRuns() =>
    int.tryParse(Platform.environment['FMFA_FUZZ_RUNS'] ?? '') ?? 10000;

/// Deterministic generator for reproducible fuzz failures. Tests only;
/// library code must use `Random.secure()`.
Random fuzzRandom([int seed = 0x5eed]) => Random(seed);
