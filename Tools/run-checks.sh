#!/usr/bin/env bash
# Compiles and runs Soldo's logic checks on the host Mac: the Obsidian renderer and
# vault writer against a real temporary folder, the receipt parser against real
# receipt text, and the place-category lookup table. No simulator involved.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${TMPDIR:-/tmp}/soldo-checks"
mkdir -p "$BUILD_DIR"

xcrun swiftc -O -o "$BUILD_DIR/checks" \
  Shared/AppGroup.swift \
  Shared/Money.swift \
  Soldo/Obsidian/ObsidianSettings.swift \
  Soldo/Obsidian/ObsidianVaultLink.swift \
  Soldo/Obsidian/ObsidianRenderer.swift \
  Soldo/Obsidian/ObsidianSyncEngine.swift \
  Soldo/Location/PlaceCategoryTable.swift \
  Soldo/Receipt/ReceiptScan.swift \
  Soldo/Receipt/ReceiptParser.swift \
  Tests/ObsidianChecks/main.swift

"$BUILD_DIR/checks"
