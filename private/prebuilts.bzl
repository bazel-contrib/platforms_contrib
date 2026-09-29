"""Prebuilt CPU feature detector URLs and integrity hashes."""

visibility("private")

# Detectors keyed by @platforms//host's (os, cpu) constraints. Hosts without an entry get no CPU
# feature constraints. Currently only x86-64 is supported.
#
# Run release-prebuilts.sh to build and publish //prebuilt via the prebuilts.yaml workflow.
# Copy the release notes' snippets here and into MODULE.bazel's use_repo; host_detection creates
# an http_file repo for each entry using prebuilt_detector_repo_name.
PREBUILT_DETECTORS = {
    (Label("@platforms//os:linux"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.2/detect_cpu_linux_x86_64",
        integrity = "sha256-w7R6rk3e8A3pVzM8McwhetfV/LTG/LmzXhIg7E92ha4=",
    ),
    (Label("@platforms//os:osx"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.2/detect_cpu_macos_x86_64",
        integrity = "sha256-Dlf5VghRDsiNvO0zQFJ+4D4NCMo73UJ1ol6r+h+qEXs=",
    ),
    (Label("@platforms//os:windows"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.2/detect_cpu_windows_x86_64.exe",
        integrity = "sha256-o+sEXkJWSHvisgqYYHlihRCr4AlQad8oVct/fbkCIWE=",
    ),
}

def prebuilt_detector_repo_name(os, cpu):
    """Returns the detector's http_file repo name for the given OS and CPU constraints."""
    return "detect_cpu_{os}_{cpu}".format(os = os.name, cpu = cpu.name)

def prebuilt_detector_file_name(prebuilt):
    """Returns the detector filename, preserving its extension (e.g. .exe)."""
    return prebuilt.url.rsplit("/", 1)[-1]
