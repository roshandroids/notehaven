#!/usr/bin/env bash
# Full local gate; CI runs the same steps. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-fvm flutter}"
DART="${DART:-fvm dart}"

$FLUTTER pub get
(cd app && $DART run build_runner build)
# Generated *.g.dart and gen-l10n files are not committed, so they are not format-checked.
find app/lib app/test packages tool -name '*.dart' ! -name '*.g.dart' ! -name 'app_localizations*.dart' -print0 \
  | xargs -0 $DART format --output=none --set-exit-if-changed
$FLUTTER analyze
$DART run tool/bin/check_boundaries.dart
(cd tool && $DART test)
(cd packages/notehaven_core && $DART test)
(cd packages/notehaven_sync && $DART test)
(cd packages/notehaven_sync_rest && $DART test)
(cd app && $FLUTTER test)
echo "verify: all checks passed"
