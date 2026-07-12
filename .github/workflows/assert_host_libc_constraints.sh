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

# //host:host may also carry other detected constraint values (e.g. CPU features); only its libc
# constraint values are asserted here.
filter_libc_constraints() {
    tr -d '[]' | tr ' ' '\n' | { grep -F '//os/linux/libc/' || true; } | sort
}

actual="$(bazel query --output=build //host:host | buildozer -stdout 'print constraint_values' -:host | filter_libc_constraints)"
want="$(bazel query --output=build //smoke_test:want | buildozer -stdout 'print constraint_values' -:want | filter_libc_constraints)"
echo "actual: $actual"
echo "want:   $want"
test "$actual" = "$want"
