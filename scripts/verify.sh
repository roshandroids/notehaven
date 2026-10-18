#!/usr/bin/env bash
# Full local gate; CI runs the same steps. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-fvm flutter}"
DART="${DART:-fvm dart}"

$FLUTTER pub get
$DART format --output=none --set-exit-if-changed app/lib app/test packages tool
$FLUTTER analyze
$DART run tool/bin/check_boundaries.dart
(cd tool && $DART test)
(cd packages/notehaven_core && $DART test)
(cd app && $FLUTTER test)
echo "verify: all checks passed"
