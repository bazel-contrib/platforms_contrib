"""Repository rule that detects the host's libc family and version.

Pipeline:

1. On non-Linux hosts the rule emits an empty constraint list and returns
   immediately. Every other relevant constraint is already known at
   compile time, so no detection is needed.

2. On Linux it tries the prebuilt detector pinned in
   `private/detector/prebuilts.json` (hermetic-llvm-style index of
   GitHub-release-hosted binaries). If no pin covers the host or the
   index has no `latest_version` yet, it falls back to compiling the
   detector from source using `$CC`, `clang`, `gcc`, or `cc`.

3. The detector emits one repo-relative label per detected libc family,
   embedding the *raw* host version (e.g.
   `//os/linux/libc/glibc:at_least_2.41_available`). It does not know
   which `at_least_*_available` constraints actually exist.

4. The rule loads `GLIBC_VERSIONS` and `MUSL_VERSIONS` from the
   `*_private.bzl` files and clips each detected version to the highest
   supported value. The clipped label is wrapped in `Label(...)` and
   exposed as `HOST_CONSTRAINT_VALUES` in the generated `host.bzl`.
"""

load("//os/linux/libc/glibc:glibc_private.bzl", "GLIBC_VERSIONS")
load("//os/linux/libc/musl:musl_private.bzl", "MUSL_VERSIONS")

visibility("//...")

_PREBUILTS_INDEX = Label("//private/detector:prebuilts.json")
_DETECTOR_SOURCE = Label("//private/detector:src/detector.c")

_COMPILER_CANDIDATES = ["clang", "gcc", "cc"]

# Per-family version range used for clipping the detector's output.
_VERSION_RANGES = {
    "//os/linux/libc/glibc": GLIBC_VERSIONS,
    "//os/linux/libc/musl": MUSL_VERSIONS,
}

def _host_target(repository_ctx):
    """Returns the hermetic-llvm-style "<os>-<cpu>" key (or None for non-Linux)."""
    os_name = repository_ctx.os.name.lower()
    if not os_name.startswith("linux"):
        return None

    arch = repository_ctx.os.arch.lower()
    if arch in ("x86_64", "amd64", "x64"):
        return "linux-amd64"
    if arch in ("aarch64", "arm64"):
        return "linux-arm64"
    fail("Unsupported Linux host CPU for platforms_contrib host detection: " + arch)

def _read_prebuilts_index(repository_ctx):
    content = repository_ctx.read(repository_ctx.path(_PREBUILTS_INDEX))
    return json.decode(content)

def _prebuilt_spec(repository_ctx, target):
    index = _read_prebuilts_index(repository_ctx)
    version = index.get("latest_version")
    if version == None:
        return None
    release = index.get("releases", {}).get(version)
    if release == None:
        return None
    return release.get(target)

def _download_prebuilt(repository_ctx, target):
    spec = _prebuilt_spec(repository_ctx, target)
    if spec == None:
        return None
    repository_ctx.download(
        url = spec["url"],
        sha256 = spec["sha256"],
        output = "detector",
        executable = True,
    )
    return "detector"

def _compile_from_source(repository_ctx):
    source = repository_ctx.path(_DETECTOR_SOURCE)

    cc_env = repository_ctx.os.environ.get("CC", "").strip()
    candidates = []
    if cc_env:
        candidates.append(cc_env)
    candidates.extend(_COMPILER_CANDIDATES)

    tried = []
    last_error = ""
    for compiler in candidates:
        path = repository_ctx.which(compiler)
        if path == None:
            continue
        tried.append(str(path))
        result = repository_ctx.execute(
            [str(path), "-std=c11", "-Os", "-o", "detector", str(source)],
            timeout = 120,
        )
        if result.return_code == 0:
            return "detector"
        last_error = "{}: exit {}\n{}\n{}".format(
            str(path),
            result.return_code,
            result.stdout,
            result.stderr,
        )

    if not tried:
        fail(
            "platforms_contrib host detection needs a C compiler in PATH (set $CC or install " +
            "one of {}); none found.".format(_COMPILER_CANDIDATES),
        )
    fail("platforms_contrib host detector failed to compile from source.\nLast error:\n" + last_error)

def _parse_version(s):
    """Parses "2.39" into (2, 39). Returns None if malformed."""
    parts = s.split(".")
    if len(parts) != 2:
        return None
    if not (parts[0].isdigit() and parts[1].isdigit()):
        return None
    return (int(parts[0]), int(parts[1]))

def _clip_to_supported(detected, supported):
    """Returns the highest version in `supported` that is <= `detected`, or None."""
    detected_tuple = _parse_version(detected)
    if detected_tuple == None:
        return None
    best = None
    for v in supported:
        v_tuple = _parse_version(v)
        if v_tuple == None:
            continue
        if v_tuple <= detected_tuple and (best == None or v_tuple > _parse_version(best)):
            best = v
    return best

def _clip_label(raw_label):
    """Clips a detector-emitted label to one that actually exists in the repo.

    Returns the clipped label, or None if the detected version is older than
    the lowest supported one (meaning the host predates everything we track,
    so no constraint applies).
    """
    pkg, sep, suffix = raw_label.partition(":at_least_")
    if not sep or not suffix.endswith("_available"):
        fail("platforms_contrib detector emitted unexpected label: " + raw_label)
    if pkg not in _VERSION_RANGES:
        fail("platforms_contrib detector emitted label for unknown package: " + raw_label)

    detected = suffix[:-len("_available")]
    clipped = _clip_to_supported(detected, _VERSION_RANGES[pkg])
    if clipped == None:
        return None
    return "{}:at_least_{}_available".format(pkg, clipped)

def _parse_labels(stdout):
    raw_labels = []
    for raw in stdout.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not line.startswith("//"):
            fail("platforms_contrib detector emitted non-repo-relative label: " + line)
        raw_labels.append(line)
    return raw_labels

def _write_outputs(repository_ctx, source, raw_labels, clipped_labels):
    label_calls = [
        "Label(\"@platforms_contrib{}\")".format(label)
        for label in clipped_labels
    ]
    rendered_list = "[\n" + "".join(["    " + call + ",\n" for call in label_calls]) + "]"

    raw_block = "".join(["#   raw:     " + l + "\n" for l in raw_labels])
    clipped_block = "".join(["#   clipped: " + l + "\n" for l in clipped_labels])
    if not raw_block:
        raw_block = "#   (none)\n"

    repository_ctx.file(
        "BUILD.bazel",
        "# Generated by @platforms_contrib//private:host_detect.bzl.\n" +
        "exports_files([\"host.bzl\"])\n",
    )
    repository_ctx.file(
        "host.bzl",
        "# Generated by @platforms_contrib//private:host_detect.bzl.\n" +
        "# Source: " + source + "\n" +
        "# Detector output:\n" +
        raw_block +
        clipped_block +
        "\n" +
        "HOST_CONSTRAINT_VALUES = " + rendered_list + "\n",
    )

def _host_detect_impl(repository_ctx):
    target = _host_target(repository_ctx)
    if target == None:
        _write_outputs(repository_ctx, "non-linux", [], [])
        return

    binary_name = _download_prebuilt(repository_ctx, target)
    source = "prebuilt"
    if binary_name == None:
        binary_name = _compile_from_source(repository_ctx)
        source = "compiled"

    result = repository_ctx.execute(
        [repository_ctx.path(binary_name)],
        timeout = 30,
    )
    if result.return_code != 0:
        fail("platforms_contrib host detector exited with code {}\nstdout:\n{}\nstderr:\n{}".format(
            result.return_code,
            result.stdout,
            result.stderr,
        ))

    raw_labels = _parse_labels(result.stdout)
    clipped_labels = []
    for label in raw_labels:
        clipped = _clip_label(label)
        if clipped != None:
            clipped_labels.append(clipped)

    _write_outputs(repository_ctx, source, raw_labels, clipped_labels)

host_detect = repository_rule(
    implementation = _host_detect_impl,
    configure = True,
    environ = ["CC", "PATH"],
    doc = "Detects host libc properties by running a (downloaded or freshly compiled) detector binary.",
)
