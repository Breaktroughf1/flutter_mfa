#!/usr/bin/env bash
# Golden tests (tag `golden`) for flutter_mfa_ui. Only valid on the pinned Linux
# CI image (G8); `--update` regenerates them for an intended visual change.
set -euo pipefail
cd "$(dirname "$0")/../packages/flutter_mfa_ui"
if [ ! -d test/goldens ]; then echo "skip: no goldens yet"; exit 0; fi
if [ "${1:-}" = "--update" ]; then
  flutter test --tags golden --update-goldens
else
  flutter test --tags golden
fi
