#!/usr/bin/env bash
# Compiles and runs the Obsidian export checks on the host Mac.
# These exercise the renderer and the vault writer against a real temporary folder,
# with no simulator involved.
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
  Tests/ObsidianChecks/main.swift

"$BUILD_DIR/checks"
