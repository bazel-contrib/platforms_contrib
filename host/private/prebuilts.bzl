"""URLs and integrity hashes of the prebuilt CPU feature detector binaries."""

visibility(["//host/..."])

# Prebuilt detect_cpu binaries, cross-compiled by //prebuilt and published as GitHub release
# artifacts by the prebuilts.yaml workflow whenever a `prebuilts-v*` tag is pushed (see
# release-prebuilts.sh). Keyed by (os, arch) as normalized in host_platform.bzl. Entry shape:
#
#     ("linux", "amd64"): struct(
#         url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.1/detect_cpu_linux_amd64",
#         integrity = "sha256-...",
#     ),
#
# The workflow prints a ready-to-paste snippet for this dict in the release notes. On hosts with
# no matching entry, host platform detection emits a warning and doesn't declare any CPU feature
# constraint values (see host_platform.bzl).
PREBUILT_DETECTORS = {}
