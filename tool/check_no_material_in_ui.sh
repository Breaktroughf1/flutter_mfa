#!/usr/bin/env bash
# flutter_mfa_ui and flutter_mfa_qr build on the widgets layer only (ADR-0006).
# Only the two adapter files in flutter_mfa_ui may import Material/Cupertino.
# flutter_mfa_ui also depends on flutter_mfa_core only (02_ARCHITECTURE.md §3).
set -euo pipefail
cd "$(dirname "$0")/.."
LIBS=$(ls -d packages/flutter_mfa_ui/lib packages/flutter_mfa_qr/lib 2>/dev/null || true)
[ -n "$LIBS" ] || { echo "skip: ui/qr not created yet"; exit 0; }
fail=0

BAD=$(grep -rlE "^\s*(import|export)\b.*['\"]package:flutter/(material|cupertino)\.dart" $LIBS \
  | grep -vE "^packages/flutter_mfa_ui/lib/src/theme/(material|cupertino)_adapter\.dart$" || true)
if [ -n "$BAD" ]; then
  echo "ERROR: Material/Cupertino imported outside the adapters:"; echo "$BAD"; fail=1
fi

if [ -d packages/flutter_mfa_ui/lib ]; then
  if hits=$(grep -rnE "^\s*(import|export)\b.*['\"]package:(flutter_mfa|flutter_mfa_platform_interface|flutter_mfa_qr)/" packages/flutter_mfa_ui/lib); then
    echo "ERROR: flutter_mfa_ui must not import flutter_mfa, flutter_mfa_platform_interface, or flutter_mfa_qr:"
    echo "$hits"; fail=1
  fi
fi

if [ -f packages/flutter_mfa_ui/pubspec.yaml ]; then
  if hits=$(grep -nE "^\s+(flutter_mfa|flutter_mfa_platform_interface|flutter_mfa_qr):" packages/flutter_mfa_ui/pubspec.yaml); then
    echo "ERROR: flutter_mfa_ui pubspec.yaml must not depend on flutter_mfa, flutter_mfa_platform_interface, or flutter_mfa_qr:"
    echo "$hits"; fail=1
  fi
fi

[ $fail -eq 0 ] && echo "ok: ui and qr are design-system independent" || exit 1
