"""Detects host CPU features for //host:native."""

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//cpu/x86_64:model.bzl", "x86_64_model_flags")
load(":feature_mapping.bzl", "x86_64_feature_constraint_names")
load(":prebuilts.bzl", "PREBUILT_DETECTORS", "prebuilt_detector_file_name", "prebuilt_detector_repo_name")

visibility("private")

# HOST_CONSTRAINTS contains strings, so the platforms module must use the repo name "platforms".
_HOST_CONSTRAINTS = [Label(constraint) for constraint in HOST_CONSTRAINTS]

def _find_prebuilt_detector():
    """Returns the host's prebuilt detector label, or None if unsupported."""
    for (os, cpu), prebuilt in PREBUILT_DETECTORS.items():
        if os in _HOST_CONSTRAINTS and cpu in _HOST_CONSTRAINTS:
            return Label("@{repo}//file:{file}".format(
                repo = prebuilt_detector_repo_name(os, cpu),
                file = prebuilt_detector_file_name(prebuilt),
            ))
    return None

def _detect_x86_64_features(rctx):
    """Returns the detector report, or None on unsupported hosts."""
    detector = _find_prebuilt_detector()
    if not detector:
        return None

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

def _cpu_feature_constraints_impl(rctx):
    report = _detect_x86_64_features(rctx)
    feature_names = x86_64_feature_constraint_names(report) if report != None else []

    # LLVM reports "generic" for CPUs it doesn't know.
    model = report["cpu"] if report != None and report["cpu"] != "generic" else ""
    platform_flags = x86_64_model_flags(model) if model else []

    rctx.file("BUILD.bazel", 'exports_files(["constraints.bzl"])\n')
    rctx.file("constraints.bzl", "CPU_FEATURE_CONSTRAINTS = [\n{}]\n".format("".join([
        # repr() of a main repository Label omits the leading @@.
        "    Label({}),\n".format(repr(str(Label("//cpu/x86_64/feature:" + name))))
        for name in feature_names
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
