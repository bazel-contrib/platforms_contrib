#!/usr/bin/env bash
set -euo pipefail

# The expected detected libc constraints and those of //host:generic, which floors the glibc
# version. The latter default to the former.
expected="$1"
expected_generic="${2:-$1}"

bazel build --config=ci //host:generic

# Include the OS and CPU constraints inlined by //host:generic (see host/BUILD.bazel).
mkdir -p smoke_test
cat > smoke_test/BUILD.bazel <<EOF
load("@libc_constraints//:constraints.bzl", "LIBC_CONSTRAINTS")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("//os/linux/libc/musl:musl.bzl", "musl_version_constraints")
platform(name = "detected", constraint_values = HOST_CONSTRAINTS + LIBC_CONSTRAINTS)
platform(name = "want", constraint_values = HOST_CONSTRAINTS + $expected)
platform(name = "want_generic", constraint_values = HOST_CONSTRAINTS + $expected_generic)
EOF

constraint_values() {
  bazel query --output=build "$1" | buildozer -stdout 'print constraint_values' "-:${1##*:}"
}

check() {
  local actual want
  actual="$(constraint_values "$1")"
  want="$(constraint_values "$2")"
  echo "$1: $actual"
  echo "$2: $want"
  test "$actual" = "$want"
}

check //smoke_test:detected //smoke_test:want
check //host:generic //smoke_test:want_generic
