#!/usr/bin/env bash
# Single entry point for every Dart/Flutter test run (DRY: melos `test`,
# `coverage` and CI all call this).
#
#   tool/test.sh              VM unit + widget tests, then browser tests
#   tool/test.sh --coverage   same, plus line + branch coverage gates
#                             (NFR-01/02, ADR-0008): core 95/90, others 85/75
#
# Layout rules:
#   pure Dart pkgs   VM tests also run in Chrome via dart2js and dart2wasm.
#   test/web/**      browser-only tests (`@TestOn('browser')`), run in Chrome.
#                    Chrome runs produce no coverage, so web-only libraries are
#                    gated by these tests, not by lcov (ADR-0008).
#   tag `golden`     excluded here; run by `melos run test:goldens` on the pinned
#                    CI image only.
# A package with code under lib/src/ and no tests at all fails.
set -euo pipefail
cd "$(dirname "$0")/.."

COVERAGE=0
[ "${1:-}" = "--coverage" ] && COVERAGE=1

CHROME="${CHROME_EXECUTABLE:-$(command -v google-chrome || command -v chromium || true)}"
[ -n "$CHROME" ] && export CHROME_EXECUTABLE="$CHROME"

vm_tests() { # dir -> test files outside test/web
  [ -d "$1/test" ] || return 0
  (cd "$1" && find test -name '*_test.dart' -not -path 'test/web/*' | sort)
}

run() { # dir, min lines, min branches (empty = no gate, e.g. example apps)
  local dir=$1 files
  files=$(vm_tests "$dir")
  if [ -z "$files" ]; then
    if [ -d "$dir/lib/src" ] && [ ! -d "$dir/test/web" ]; then
      echo "ERROR: $dir has code in lib/src but no tests"; return 1
    fi
    echo "skip (no VM tests): $dir"
  else
    local args=(--exclude-tags golden)
    local gated=$((COVERAGE == 1 && ${#2} > 0))
    if [ $gated -eq 1 ]; then
      args+=(--coverage-path=coverage/lcov.info --branch-coverage)
    fi
    echo "== $dir"
    if grep -qE '^\s+sdk: flutter' "$dir/pubspec.yaml"; then
      # shellcheck disable=SC2086
      (cd "$dir" && flutter test "${args[@]}" $files)
    else
      # shellcheck disable=SC2086
      (cd "$dir" && dart test "${args[@]}" $files)
      # Pure Dart packages must also be correct when compiled to JS and WASM (NFR-07).
      if need_chrome "$dir (dart2js/dart2wasm)"; then
        # shellcheck disable=SC2086
        (cd "$dir" && dart test -p chrome $files && dart test -p chrome -c dart2wasm $files)
      fi
    fi
    if [ $gated -eq 1 ]; then
      dart run tool/coverage_gate.dart "$dir/coverage/lcov.info" --lines "$2" --branches "$3"
    fi
  fi
  if [ -d "$dir/test/web" ] && need_chrome "$dir/test/web"; then
    # Web-only code must work compiled to both JS and WASM (NFR-07).
    (cd "$dir" && flutter test --platform chrome test/web &&
      flutter test --platform chrome --wasm test/web)
  fi
}

need_chrome() { # label -> 0 if Chrome is available; fails in CI without it
  if [ -n "${CHROME_EXECUTABLE:-}" ]; then echo "== $1 (chrome)"; return 0; fi
  if [ -n "${CI:-}" ]; then echo "ERROR: no Chrome for $1"; exit 1; fi
  echo "WARNING: no Chrome found; skipping $1"
  return 1
}

run packages/flutter_mfa_core 95 90
for p in flutter_mfa_platform_interface flutter_mfa flutter_mfa_ui flutter_mfa_qr; do
  run "packages/$p" 85 75
done
for e in packages/*/example; do
  [ -f "$e/pubspec.yaml" ] && run "$e" "" ""
done
echo "ok: all tests passed$([ $COVERAGE -eq 1 ] && echo ' and coverage gates met')"
