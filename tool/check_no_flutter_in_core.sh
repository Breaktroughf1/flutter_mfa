#!/usr/bin/env bash
# flutter_mfa_core must stay pure Dart (ADR-0001, ADR-0002).
set -euo pipefail
CORE=packages/flutter_mfa_core
[ -d "$CORE" ] || { echo "skip: $CORE not created yet"; exit 0; }
if grep -rnE "package:flutter/|dart:ui|dart:html" "$CORE/lib" "$CORE/bin" 2>/dev/null; then
  echo "ERROR: flutter_mfa_core must not import Flutter, dart:ui or dart:html"; exit 1
fi
if grep -nE "^\s+flutter:" "$CORE/pubspec.yaml"; then
  echo "ERROR: flutter_mfa_core pubspec must not depend on flutter"; exit 1
fi
echo "ok: core is pure Dart"
