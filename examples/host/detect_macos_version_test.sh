#!/usr/bin/env bash

set -euo pipefail

output="$(cat "$1")"
echo "detected: ${output}"
# Every macOS version since 11 is floored to its major version.
expected="$(sw_vers -productVersion | cut -d. -f1).0"
if [[ "${output}" != "${expected}" ]]; then
    echo "expected macOS ${expected} to be detected" >&2
    exit 1
fi
