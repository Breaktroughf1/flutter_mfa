#!/usr/bin/env bash
# Security guard (04_SECURITY_DESIGN.md §6–7, CLAUDE.md rules 2–3).
# Scans published library code and native vault code. Comment lines are ignored.
set -euo pipefail
cd "$(dirname "$0")/.."
LIBS=$(ls -d packages/*/lib 2>/dev/null || true)
[ -n "$LIBS" ] || { echo "skip: no packages yet"; exit 0; }
fail=0
COMMENT=':[0-9]+:[[:space:]]*(//|/?\*|#)'

check() { # pattern, message, paths, [exclude-regex]
  local hits
  hits=$(grep -rnE "$1" $3 2>/dev/null | grep -vE "$COMMENT" | grep -vE "${4:-^$}" || true)
  if [ -n "$hits" ]; then echo "ERROR: $2"; echo "$hits"; fail=1; fi
}

# Dart library code
check '\bRandom\(' 'non-secure Random(...) in lib (use Random.secure(); fakes belong in testing.dart)' "$LIBS" '/testing\.dart:|/src/testing/'
check '\b(print|debugPrint)\(' 'print/debugPrint in lib (use MfaLogger)' "$LIBS"
check '\bconsole\.(log|info|warn|error|debug)\b' 'browser console logging in lib (use MfaLogger)' "$LIBS"
check 'dart:html' 'dart:html is not WASM-compatible (use package:web)' "$LIBS"
check '\b(md5|MD5)\b' 'MD5 is forbidden' "$LIBS"
check 'AES/ECB|AES/CBC|\bECB\b|\bCBC\b' 'ECB/CBC modes are forbidden (use AES-GCM)' "$LIBS"
check 'package:http/|HttpClient\(|\bfetch\(' 'network I/O is not allowed in library code (MASVS-NETWORK N/A by design)' "$LIBS"

# Native vault code: no logging at all (values could leak; levels are reported via capabilities).
NATIVE=$(ls -d packages/flutter_mfa/android/src/main packages/flutter_mfa/ios/flutter_mfa/Sources 2>/dev/null || true)
if [ -n "$NATIVE" ]; then
  check '\bLog\.(v|d|i|w|e|wtf)\(|\bprintln\(|System\.(out|err)|\bNSLog\(|\bprint\(|\bdebugPrint\(|\bos_log\(|Logger\(' \
    'logging in native vault code' "$NATIVE"
  check 'AES/ECB|AES/CBC|"MD5"|\.md5|kCCAlgorithm|CC_MD5' 'weak native crypto' "$NATIVE"
fi

if [ $fail -eq 0 ]; then echo "ok: no forbidden APIs"; else exit 1; fi
