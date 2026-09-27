#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <version>" >&2
    echo "  version may be either 0.0.1 or v0.0.1" >&2
    exit 1
fi

version=$1

if [[ "${version}" != v* ]]; then
    version="v${version}"
fi

git tag -a "prebuilts-${version}" -m "publish prebuilts for ${version}"
git push origin "prebuilts-${version}"
