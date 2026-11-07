#!/usr/bin/env bash
# flutter_mfa_ui and flutter_mfa_qr build on the widgets layer only (ADR-0006).
# Only the two adapter files in flutter_mfa_ui may import Material/Cupertino.
set -euo pipefail
cd "$(dirname "$0")/.."
LIBS=$(ls -d packages/flutter_mfa_ui/lib packages/flutter_mfa_qr/lib 2>/dev/null || true)
[ -n "$LIBS" ] || { echo "skip: ui/qr not created yet"; exit 0; }
BAD=$(grep -rlE "package:flutter/(material|cupertino)\.dart" $LIBS \
  | grep -vE "^packages/flutter_mfa_ui/lib/src/theme/(material|cupertino)_adapter\.dart$" || true)
if [ -n "$BAD" ]; then
  echo "ERROR: Material/Cupertino imported outside the adapters:"; echo "$BAD"; exit 1
fi
echo "ok: ui and qr are design-system independent"
