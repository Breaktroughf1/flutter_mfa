#!/usr/bin/env bash
# The generated localization code in flutter_mfa_ui is committed (published
# packages need it). Regenerate it and fail if it differs from the ARB files.
set -euo pipefail
cd "$(dirname "$0")/../packages/flutter_mfa_ui"
flutter gen-l10n >/dev/null
if ! git diff --quiet -- lib/src/l10n/generated || [ -n "$(git ls-files --others --exclude-standard lib/src/l10n/generated)" ]; then
  echo "ERROR: generated localizations are stale; run 'melos run l10n' and commit:"
  git status --short -- lib/src/l10n/generated
  exit 1
fi
echo "ok: generated localizations match the ARB files"
