"""Prebuilt CPU feature detector URLs and integrity hashes."""

visibility("private")

# Keys are @platforms//host's (os, cpu) labels; unlisted hosts get no CPU feature constraints.
#
# Run release-prebuilts.sh, then copy the release notes' snippet here. After adding a platform,
# run `bazel mod tidy` to add its detector repo to MODULE.bazel.
PREBUILT_DETECTORS = {
    (Label("@platforms//os:linux"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.3/detect_cpu_linux_x86_64",
        integrity = "sha256-wJ5C2Eg5sncahaDszbnM9CuplpI6fb3xa8y2KJ2M664=",
    ),
    (Label("@platforms//os:osx"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.3/detect_cpu_macos_x86_64",
        integrity = "sha256-GmVx0tWwfV8PfV9DHWfttdpsUNVrjgVBHFN783PfPNA=",
    ),
    (Label("@platforms//os:windows"), Label("@platforms//cpu:x86_64")): struct(
        url = "https://github.com/bazel-contrib/platforms_contrib/releases/download/prebuilts-v0.0.3/detect_cpu_windows_x86_64.exe",
        integrity = "sha256-NMstrIflkmv28/l1elebWk8TCYLLAdTLJeAShw9nVL8=",
    ),
}

def prebuilt_detector_repo_name(os, cpu):
    """Returns the detector's http_file repo name for the given OS and CPU constraints."""
    return "detect_cpu_{os}_{cpu}".format(os = os.name, cpu = cpu.name)

def prebuilt_detector_file_name(prebuilt):
    """Returns the detector filename, preserving its extension (e.g. .exe)."""
    return prebuilt.url.rsplit("/", 1)[-1]
