#!/usr/bin/env bash
# Generates Schei.xcodeproj from project.yml.
# The Xcode project is not committed: XcodeGen rebuilds it from the spec.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen…"
    brew install xcodegen
  else
    echo "XcodeGen is required: https://github.com/yonaskolb/XcodeGen" >&2
    exit 1
  fi
fi

xcodegen generate
echo "Done. Open Schei.xcodeproj."
