#!/usr/bin/env bash
set -euo pipefail

expected="$1"

bazel build --config=ci //host:host

mkdir -p smoke_test
cat > smoke_test/BUILD.bazel <<EOF
load("//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("//os/linux/libc/musl:musl.bzl", "musl_version_constraints")
platform(name = "want", constraint_values = $expected)
EOF

actual="$(bazel query --output=build //host:host | buildozer -stdout 'print constraint_values' -:host)"
want="$(bazel query --output=build //smoke_test:want | buildozer -stdout 'print constraint_values' -:want)"
echo "actual: $actual"
echo "want:   $want"
test "$actual" = "$want"
