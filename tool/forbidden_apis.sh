#!/usr/bin/env bash
# Security guard (04_SECURITY_DESIGN.md §6–7). Scans published library code only.
set -euo pipefail
LIBS=$(ls -d packages/*/lib 2>/dev/null || true)
[ -n "$LIBS" ] || { echo "skip: no packages yet"; exit 0; }
fail=0
check() { # pattern, message, [exclude-regex]
  local hits
  hits=$(grep -rnE "$1" $LIBS 2>/dev/null | grep -vE "${3:-^$}" || true)
  if [ -n "$hits" ]; then echo "ERROR: $2"; echo "$hits"; fail=1; fi
}
check '\bRandom\(\)' 'non-secure Random() in lib (use Random.secure(); fakes belong in testing.dart)' '/testing\.dart:|/src/testing/'
check '\b(print|debugPrint)\(' 'print/debugPrint in lib (use MfaLogger)'
check 'dart:html' 'dart:html is not WASM-compatible (use package:web)'
check '\b(md5|MD5)\b' 'MD5 is forbidden'
check 'AES/ECB|AES/CBC|\bECB\b' 'ECB/CBC modes are forbidden (use AES-GCM)'
check 'package:http/|HttpClient\(' 'network I/O is not allowed in library code (MASVS-NETWORK N/A by design)'
# Native code
NATIVE=$(ls -d packages/flutter_mfa/android/src packages/flutter_mfa/ios 2>/dev/null || true)
if [ -n "$NATIVE" ]; then
  hits=$(grep -rnE 'Log\.(d|v|i)\(|NSLog\(|print\(' $NATIVE 2>/dev/null | grep -vE '/(test|androidTest|Tests)/' || true)
  [ -z "$hits" ] || { echo "ERROR: debug logging in native vault code"; echo "$hits"; fail=1; }
fi
[ $fail -eq 0 ] && echo "ok: no forbidden APIs" || exit 1
