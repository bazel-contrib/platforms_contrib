"""URLs and integrity hashes of the prebuilt CPU feature detector binaries."""

visibility("private")

# Prebuilt detect_cpu binaries, cross-compiled by //prebuilt and published as GitHub release
# artifacts by the prebuilts.yaml workflow whenever a `prebuilts-v*` tag is pushed (see
# release-prebuilts.sh). Keyed by the (os, cpu) constraint values that @platforms//host reports
# for the hosts the binary runs on. The host_detection module extension backs each entry with an
# http_file repo named by prebuilt_detector_repo_name, which also has to be listed in
# MODULE.bazel's use_repo. For now, binaries are only built for x86-64 hosts. Entry shape:
#
#     (Label("@platforms//os:linux"), Label("@platforms//cpu:x86_64")): struct(
#         url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.1/detect_cpu_linux_x86_64",
#         integrity = "sha256-...",
#     ),
#
# The workflow prints a ready-to-paste snippet for this dict in the release notes. On hosts with
# no matching entry, host platform detection doesn't declare any CPU feature constraint values
# (see cpu_feature_constraints.bzl).
PREBUILT_DETECTORS = {
    (Label("@platforms//os:linux"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.1/detect_cpu_linux_x86_64",
        integrity = "sha256-X9fLbdVBk4vtFpLbAMIqDyl1j/AS6We+nkCZn8+sL3g=",
    ),
    (Label("@platforms//os:osx"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.1/detect_cpu_macos_x86_64",
        integrity = "sha256-IHaxcTtQAHnd6u6SiSz0Aa/Dk+wTT9sH0Ol73b8QpYw=",
    ),
    (Label("@platforms//os:windows"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.1/detect_cpu_windows_x86_64.exe",
        integrity = "sha256-j7yWZOAVaFksbIw38Tc5FE/Z8X7vX+rtX85sQb4WqAU=",
    ),
}

def prebuilt_detector_repo_name(os, cpu):
    """Returns the name of the http_file repo backing the detector for the given constraints."""
    return "detect_cpu_{os}_{cpu}".format(os = os.name, cpu = cpu.name)

def prebuilt_detector_file_name(prebuilt):
    """Returns the name of the file in the http_file repo, preserving any extension (.exe)."""
    return prebuilt.url.rsplit("/", 1)[-1]
