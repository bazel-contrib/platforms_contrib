#!/usr/bin/env python3
"""Regenerate private/detector/prebuilts.json from a SHA256SUMS manifest.

The manifest is the output of `shasum -a 256 detector-*` (one
"<hex>  <asset>" line per release asset). Asset names follow the pattern
"detector-<target>", where <target> is e.g. "linux-amd64".

Output schema (mirrors hermeticbuild/hermetic-llvm's index format):

  {
    "latest_version": "detector-abc123",
    "releases": {
      "detector-abc123": {
        "linux-amd64": {"url": "...", "sha256": "..."},
        "linux-arm64": {"url": "...", "sha256": "..."}
      }
    }
  }
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def asset_to_target(asset: str) -> str:
    if not asset.startswith("detector-"):
        raise ValueError(f"unexpected asset name: {asset!r}")
    return asset[len("detector-") :]


def parse_sha_manifest(text: str) -> dict[str, tuple[str, str]]:
    """Returns {target: (asset, sha256)}."""
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
        entries[asset_to_target(asset)] = (asset, sha)
    return entries


def render(tag: str, repo: str, entries: dict[str, tuple[str, str]]) -> str:
    release = {}
    for target in sorted(entries):
        asset, sha = entries[target]
        release[target] = {
            "url": f"https://github.com/{repo}/releases/download/{tag}/{asset}",
            "sha256": sha,
        }
    index = {
        "latest_version": tag,
        "releases": {tag: release},
    }
    return json.dumps(index, indent=2, sort_keys=True) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True, help="release tag, e.g. detector-abc123")
    parser.add_argument("--shas", required=True, type=Path, help="SHA256SUMS manifest")
    parser.add_argument("--repo", required=True, help="GitHub owner/repo, e.g. bazel-contrib/platforms_contrib")
    parser.add_argument("--output", required=True, type=Path, help="prebuilts.json path")
    args = parser.parse_args(argv)

    entries = parse_sha_manifest(args.shas.read_text())
    if not entries:
        print("error: no entries parsed from manifest", file=sys.stderr)
        return 1
    args.output.write_text(render(args.tag, args.repo, entries))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
