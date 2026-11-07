#!/usr/bin/env bash
# flutter_mfa_core must stay pure Dart and compile to VM, JS and WASM
# (ADR-0001, ADR-0002, CLAUDE.md rules 6 and 9).
set -euo pipefail
cd "$(dirname "$0")/.."
CORE=packages/flutter_mfa_core
[ -d "$CORE" ] || { echo "skip: $CORE not created yet"; exit 0; }
fail=0

# Imports that break pure-Dart or web/WASM compilation of the published library.
SRC=$(ls -d "$CORE/lib" "$CORE/bin" 2>/dev/null || true)
if hits=$(grep -rnE "^\s*(import|export)\s+['\"](package:flutter/|dart:(ui|html|io|isolate|ffi|mirrors))" $SRC); then
  echo "ERROR: flutter_mfa_core lib must not import Flutter, dart:ui/html/io/isolate/ffi/mirrors:"
  echo "$hits"; fail=1
fi

# Dependency allowlist: crypto, meta, collection + the AEAD/KDF package of ADR-0007.
ALLOWED='^(crypto|meta|collection|cryptography|pointycastle)$'
deps=$(awk '/^dependencies:/{f=1;next} /^[^[:space:]#]/{f=0} f && /^  [a-z_]+:/{sub(":.*","");gsub(" ","");print}' "$CORE/pubspec.yaml")
for d in $deps; do
  if ! [[ $d =~ $ALLOWED ]]; then
    echo "ERROR: flutter_mfa_core may not depend on '$d' (allowlist: crypto, meta, collection, ADR-0007 AEAD/KDF)"; fail=1
  fi
done

[ $fail -eq 0 ] && echo "ok: core is pure Dart" || exit 1
