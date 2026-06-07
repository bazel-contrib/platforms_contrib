#!/usr/bin/env python3
"""Regenerate private/detector/versions.bzl from a SHA256SUMS manifest.

The manifest is the output of `shasum -a 256 detector-*` (i.e. one
"<hex>  <asset>" line per release asset). Asset names map to host keys by
stripping the leading "detector-" and converting hyphens to underscores.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_HEADER = '''"""Pinned prebuilt detector binaries.

VERSION is a GitHub release tag of the form ``detector-<short-sha>`` produced
by the ``prebuilt-detector`` workflow. The release attaches one asset per
supported Linux host (cpu) and the workflow updates the SHA-256 values in
this file via PR. The host detection repository rule downloads the matching
asset or compiles the detector from source if no pin exists yet.
"""

'''


def asset_to_host_key(asset: str) -> str:
    if not asset.startswith("detector-"):
        raise ValueError(f"unexpected asset name: {asset!r}")
    return asset[len("detector-") :].replace("-", "_")


def parse_sha_manifest(text: str) -> dict[str, tuple[str, str]]:
    """Returns {host_key: (asset, sha256)}."""
    entries: dict[str, tuple[str, str]] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 2:
            raise ValueError(f"malformed manifest line: {raw!r}")
        sha, asset_path = parts
        asset = Path(asset_path).name
        entries[asset_to_host_key(asset)] = (asset, sha)
    return entries


def render(tag: str, entries: dict[str, tuple[str, str]]) -> str:
    lines = [_HEADER, f'VERSION = "{tag}"\n', "\n", "BINARIES = {\n"]
    for host_key in sorted(entries):
        asset, sha = entries[host_key]
        lines.append(f'    "{host_key}": {{\n')
        lines.append(f'        "asset": "{asset}",\n')
        lines.append(f'        "sha256": "{sha}",\n')
        lines.append("    },\n")
    lines.append("}\n")
    return "".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True, help="release tag, e.g. detector-abc123")
    parser.add_argument("--shas", required=True, type=Path, help="SHA256SUMS manifest")
    parser.add_argument("--output", required=True, type=Path, help="versions.bzl path")
    args = parser.parse_args(argv)

    entries = parse_sha_manifest(args.shas.read_text())
    if not entries:
        print("error: no entries parsed from manifest", file=sys.stderr)
        return 1
    args.output.write_text(render(args.tag, entries))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
