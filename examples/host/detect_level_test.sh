#!/usr/bin/env bash

set -euo pipefail

output="$(cat "$1")"
echo "detected: ${output}"
if [[ "${output}" != "x86-64-v2" && "${output}" != "x86-64-v3" && "${output}" != "x86-64-v4" ]]; then
    echo "expected at least microarchitecture level v2 to be detected on an x86-64 host" >&2
    exit 1
fi
