"""Detects host CPU features for //host:native."""

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//cpu/arm:model.bzl", "arm_model_flags")
load("//cpu/x86_64:model.bzl", "x86_64_model_flags")
load(":feature_mapping.bzl", "aarch64_feature_constraint_names", "x86_64_feature_constraint_names")
load(":prebuilts.bzl", "PREBUILT_DETECTORS", "prebuilt_detector_file_name", "prebuilt_detector_repo_name")

visibility("private")

# HOST_CONSTRAINTS contains strings, so the platforms module must use the repo name "platforms".
_HOST_CONSTRAINTS = [Label(constraint) for constraint in HOST_CONSTRAINTS]

def _find_prebuilt_detector():
    """Returns (detector label, cpu constraint) for the host, or (None, None) if unsupported."""
    for (os, cpu), prebuilt in PREBUILT_DETECTORS.items():
        if os in _HOST_CONSTRAINTS and cpu in _HOST_CONSTRAINTS:
            detector = Label("@{repo}//file:{file}".format(
                repo = prebuilt_detector_repo_name(os, cpu),
                file = prebuilt_detector_file_name(prebuilt),
            ))
            return detector, cpu
    return None, None

def _run_detector(rctx, detector):
    """Runs the detector and returns its decoded JSON report."""
    rctx.watch(detector)
    result = rctx.execute([rctx.path(detector)])
    if result.return_code != 0:
        fail("""The CPU feature detector {detector} failed with exit code {return_code}
--- stdout ---
{stdout}
--- stderr ---
{stderr}""".format(
            detector = detector,
            return_code = result.return_code,
            stdout = result.stdout,
            stderr = result.stderr,
        ))
    return json.decode(result.stdout)

def _x86_64_constraints(report):
    # LLVM reports "generic" for CPUs it doesn't know.
    model = report["cpu"] if report["cpu"] != "generic" else ""
    return (
        x86_64_feature_constraint_names(report),
        "//cpu/x86_64/feature:",
        x86_64_model_flags(model) if model else [],
    )

def _aarch64_constraints(report):
    # The aarch64 detector reports an LLVM -mcpu name, or "" for a CPU it does not know.
    model = report["cpu"]
    return (
        aarch64_feature_constraint_names(report),
        "//cpu/aarch64/feature:",
        arm_model_flags(model) if model else [],
    )

# Maps the host's @platforms//cpu constraint name to the function that turns a detector report into
# (feature constraint names, feature constraint package, platform flags).
_CONSTRAINTS_BY_CPU = {
    "x86_64": _x86_64_constraints,
    "aarch64": _aarch64_constraints,
}

def _cpu_feature_constraints_impl(rctx):
    detector, cpu = _find_prebuilt_detector()

    feature_labels = []
    platform_flags = []
    if detector:
        handler = _CONSTRAINTS_BY_CPU.get(cpu.name)
        if not handler:
            fail("No CPU feature mapping for host CPU {}".format(cpu))
        feature_names, feature_package, platform_flags = handler(_run_detector(rctx, detector))
        feature_labels = [
            # repr() of a main repository Label omits the leading @@.
            str(Label(feature_package + name))
            for name in feature_names
        ]

    rctx.file("BUILD.bazel", 'exports_files(["constraints.bzl"])\n')
    rctx.file("constraints.bzl", "CPU_FEATURE_CONSTRAINTS = [\n{}]\n".format("".join([
        "    Label({}),\n".format(repr(label))
        for label in feature_labels
    ])) + "CPU_PLATFORM_FLAGS = {}\n".format(repr(platform_flags)))

    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(
            reproducible = False,
        )
    return None

cpu_feature_constraints = repository_rule(
    implementation = _cpu_feature_constraints_impl,
    configure = True,
)
