#!/usr/bin/env bash
set -euo pipefail

expected="$1"

bazel build --config=ci //host:generic

# Include the OS and CPU constraints inlined by //host:generic (see host/BUILD.bazel).
mkdir -p smoke_test
cat > smoke_test/BUILD.bazel <<EOF
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("//os/linux/libc/musl:musl.bzl", "musl_version_constraints")
platform(name = "want", constraint_values = HOST_CONSTRAINTS + $expected)
EOF

actual="$(bazel query --output=build //host:generic | buildozer -stdout 'print constraint_values' -:generic)"
want="$(bazel query --output=build //smoke_test:want | buildozer -stdout 'print constraint_values' -:want)"
echo "actual: $actual"
echo "want:   $want"
test "$actual" = "$want"
