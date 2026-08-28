#!/usr/bin/env bash
# Packages an unsigned .xcarchive into an .ipa that AltStore can install.
#
# The bundle is signed ad-hoc with its real entitlements so that sideloading tools
# can read which capabilities the app needs (the App Group the widget relies on).
# AltStore replaces this signature with one made from your own Apple ID.
#
# Usage: package-ipa.sh <archive-path> <output.ipa> [--no-widget]
set -euo pipefail

ARCHIVE="${1:?archive path required}"
OUTPUT="${2:?output ipa path required}"
DROP_WIDGET="${3:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# zip runs from a staging directory, so the destination has to be absolute.
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

APP_SOURCE="$ARCHIVE/Products/Applications/Soldo.app"
if [ ! -d "$APP_SOURCE" ]; then
  echo "error: $APP_SOURCE not found" >&2
  exit 1
fi

mkdir -p "$STAGE/Payload"
cp -R "$APP_SOURCE" "$STAGE/Payload/Soldo.app"
APP="$STAGE/Payload/Soldo.app"

if [ "$DROP_WIDGET" = "--no-widget" ]; then
  # Each app extension consumes one of the three slots a free Apple ID gets,
  # so the widget-free build exists for people who are at that limit.
  rm -rf "$APP/PlugIns"
  echo "Widget extension removed."
fi

# Sign inner bundles first, then the app itself.
if [ -d "$APP/PlugIns/SoldoWidgetExtension.appex" ]; then
  codesign --force --sign - --timestamp=none \
    --entitlements "$ROOT/SoldoWidget/SoldoWidget.entitlements" \
    "$APP/PlugIns/SoldoWidgetExtension.appex"
fi

codesign --force --sign - --timestamp=none \
  --entitlements "$ROOT/Soldo/Support/Soldo.entitlements" \
  "$APP"

rm -f "$OUTPUT"
(cd "$STAGE" && zip -qry "$OUTPUT" Payload)

echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -p - || true
