"""Defines the repository rule detecting the host's CPU features for the platform at //host."""

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load(":feature_mapping.bzl", "x86_64_feature_constraint_names")
load(":prebuilts.bzl", "PREBUILT_DETECTORS", "prebuilt_detector_file_name", "prebuilt_detector_repo_name")

visibility("private")

# These Label calls rely on platforms_contrib using the "platforms" repo name for the "platforms"
# module as HOST_CONSTRAINTS consists of raw label strings.
_HOST_CONSTRAINTS = [Label(constraint) for constraint in HOST_CONSTRAINTS]

def _find_prebuilt_detector():
    """Returns the label of the prebuilt detector binary matching the host platform, or None."""
    for (os, cpu), prebuilt in PREBUILT_DETECTORS.items():
        if os in _HOST_CONSTRAINTS and cpu in _HOST_CONSTRAINTS:
            return Label("@{repo}//file:{file}".format(
                repo = prebuilt_detector_repo_name(os, cpu),
                file = prebuilt_detector_file_name(prebuilt),
            ))
    return None

def _detect_x86_64_features(rctx):
    """Returns the list of constraint value names in //cpu/x86_64/feature matching the host CPU."""
    detector = _find_prebuilt_detector()
    if not detector:
        return []

    rctx.watch(detector)
    result = rctx.execute([rctx.path(detector)])
    if result.return_code != 0:
        return []

    # The detector prints one cpu_features enum name per line.
    reported_features = [line.strip() for line in result.stdout.splitlines() if line.strip()]

    return x86_64_feature_constraint_names(reported_features)

def _cpu_feature_constraints_impl(rctx):
    feature_names = []
    if Label("@platforms//cpu:x86_64") in _HOST_CONSTRAINTS:
        feature_names = _detect_x86_64_features(rctx)

    constraints = [Label("//cpu/x86_64/feature:" + name) for name in feature_names]

    rctx.file("BUILD.bazel", 'exports_files(["constraints.bzl"])\n')
    rctx.file("constraints.bzl", "CPU_FEATURE_CONSTRAINTS = {}\n".format(
        "[\n" + "".join(['    "{}",\n'.format(constraint) for constraint in constraints]) + "]" if constraints else "[]",
    ))

    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(
            reproducible = False,
        )
    else:
        return None

cpu_feature_constraints = repository_rule(
    implementation = _cpu_feature_constraints_impl,
    configure = True,
    # The reported CPU features can change without any watchable file changing, e.g. through a
    # microcode update that disables a feature, so rerun detection on every server startup.
    local = True,
)
