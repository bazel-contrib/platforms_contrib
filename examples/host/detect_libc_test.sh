#!/usr/bin/env bash

set -euo pipefail

output="$(cat "$1")"
echo "detected: ${output}"
if [[ ! "${output}" =~ glibc=2\.[0-9]+ && ! "${output}" =~ musl=1\.[0-9]+ ]]; then
    echo "expected a glibc or musl version to be detected on a Linux host" >&2
    exit 1
fi
