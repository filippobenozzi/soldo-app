#!/usr/bin/env python3
"""Adds a released build to the AltStore source at altstore/source.json.

The source is a plain JSON file served straight from the repository, so AltStore
only needs the raw.githubusercontent.com URL to see new versions.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_PATH = ROOT / "altstore" / "source.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="Marketing version, e.g. 1.0.1")
    parser.add_argument("--build", required=True, help="Build number")
    parser.add_argument("--ipa", required=True, type=pathlib.Path, help="Path to the built .ipa")
    parser.add_argument("--download-url", required=True, help="Public URL of the .ipa")
    parser.add_argument("--notes", default="", help="Release notes shown in AltStore")
    parser.add_argument("--min-os", default="17.0")
    return parser.parse_args()


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    args = parse_args()

    if not args.ipa.is_file():
        print(f"error: {args.ipa} not found", file=sys.stderr)
        return 1

    source = json.loads(SOURCE_PATH.read_text(encoding="utf-8"))
    app = source["apps"][0]

    entry = {
        "version": args.version,
        "buildVersion": str(args.build),
        "date": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "localizedDescription": args.notes.strip() or f"Soldo {args.version}",
        "downloadURL": args.download_url,
        "size": args.ipa.stat().st_size,
        "sha256": sha256(args.ipa),
        "minOSVersion": args.min_os,
    }

    # AltStore reads the first entry as the latest, so replace any same-version
    # entry in place and keep the newest first.
    versions = [v for v in app.get("versions", []) if v.get("version") != args.version]
    app["versions"] = [entry] + versions
    app["version"] = entry["version"]
    app["versionDate"] = entry["date"]
    app["versionDescription"] = entry["localizedDescription"]
    app["downloadURL"] = entry["downloadURL"]
    app["size"] = entry["size"]

    SOURCE_PATH.write_text(json.dumps(source, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Added Soldo {args.version} ({args.build}) — {entry['size']} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
