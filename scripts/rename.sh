#!/usr/bin/env bash
# One-time rename after "Use this template".
# Usage: scripts/rename.sh <snake_name> "<Display Name>"
# Example: scripts/rename.sh acme_notes "Acme Notes"
# Limit: platform folders (android, ios, macos, linux, windows, web) are NOT touched; their
# app id (org.example), binary name and display label must be renamed separately.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1:?snake_case name required}"
DISPLAY="${2:?display name required}"
[[ "$NAME" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "name must be snake_case"; exit 1; }

FILES=$(find . -type f -not -path "./.git/*" -not -path "*/.dart_tool/*" -not -path "*/build/*" -not -name pubspec.lock -not -path "./app/android/*" -not -path "./app/ios/*" -not -path "./app/macos/*" -not -path "./app/linux/*" -not -path "./app/windows/*" -not -path "./app/web/*")
for f in $FILES; do
  [[ -f "$f" ]] || continue
  [[ "$f" == scripts/rename.sh ]] && continue
  grep -Iq . "$f" || continue
  perl -pi -e "s/notehaven_/${NAME}_/g; s/package:notehaven_/package:${NAME}_/g; s/Notehaven/${DISPLAY}/g; s/name: 'notehaven'/name: '${NAME}'/g" "$f"
done
# Rename every packages/notehaven_* folder and its notehaven_*.dart barrel.
for dir in packages/notehaven_*; do
  [[ -d "$dir" ]] || continue
  suffix="${dir#packages/notehaven_}"
  mv "$dir" "packages/${NAME}_${suffix}"
  barrel="packages/${NAME}_${suffix}/lib/notehaven_${suffix}.dart"
  [[ -f "$barrel" ]] && mv "$barrel" "packages/${NAME}_${suffix}/lib/${NAME}_${suffix}.dart"
done
echo "Renamed. Run: fvm flutter pub get && scripts/verify.sh"
