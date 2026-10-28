#!/usr/bin/env bash
# flutter_mfa_ui widgets build on the widgets layer only (ADR-0006).
# Only the two adapter files may import Material/Cupertino.
set -euo pipefail
UI=packages/flutter_mfa_ui/lib
[ -d "$UI" ] || { echo "skip: $UI not created yet"; exit 0; }
BAD=$(grep -rlE "package:flutter/(material|cupertino)\.dart" "$UI" \
  | grep -vE "/(material_adapter|cupertino_adapter)\.dart$" || true)
if [ -n "$BAD" ]; then
  echo "ERROR: Material/Cupertino imported outside adapters:"; echo "$BAD"; exit 1
fi
echo "ok: ui is design-system independent"
