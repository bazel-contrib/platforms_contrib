"""Validates a CPU feature detector report and maps features to constraint values."""

load("//cpu/aarch64:aarch64_features.bzl", "AARCH64_FEATURES")
load(
    "//cpu/x86_64:x86_64_private.bzl",
    "X86_64_EXTRA_FEATURES",
    "X86_64_FEATURE_REFINEMENTS",
    "X86_64_LLVM_FEATURES",
)

visibility(["//private", "//tests"])

# Fixed x86-64 capabilities without useful driver-level disable controls.
_X86_64_FIXED_FEATURES = ["64bit", "cmov", "cx8"]
_X86_64_REPORTED_FEATURES = X86_64_LLVM_FEATURES + _X86_64_FIXED_FEATURES

def _feature_map_error(features, expected, kind):
    if type(features) != "dict":
        return "The CPU feature detector's {} must be a dictionary".format(kind)
    missing = sorted([name for name in expected if name not in features])
    unknown = sorted([name for name in features if name not in expected])
    if missing or unknown:
        return "CPU detector {} mismatch: missing [{}], unknown [{}]".format(
            kind,
            ", ".join(missing),
            ", ".join(unknown),
        )
    for name, value in features.items():
        if type(value) != "bool":
            return "CPU detector feature {} must be a boolean".format(name)
    return None

def _report_error(report):
    if type(report) != "dict":
        return "The CPU feature detector must report a JSON object"
    if type(report.get("cpu")) != "string" or not report["cpu"]:
        return "The CPU feature detector must report a nonempty cpu"
    for field, expected in [("features", _X86_64_REPORTED_FEATURES), ("extras", X86_64_EXTRA_FEATURES)]:
        error = _feature_map_error(report.get(field), expected, field)
        if error:
            return error
    for name, parent in X86_64_FEATURE_REFINEMENTS.items():
        if report["features"][name] and not report["features"][parent]:
            return "CPU detector feature {} requires {}".format(name, parent)
    return None

def x86_64_feature_constraint_names(report):
    """Returns the available or unavailable constraint name for every declared feature."""
    error = _report_error(report)
    if error:
        fail(error)
    features = report["features"] | report["extras"]
    return sorted([
        name + ("_available" if features[name] else "_unavailable")
        for name in X86_64_LLVM_FEATURES + X86_64_EXTRA_FEATURES
    ])

def _aarch64_report_error(report):
    # The aarch64 detector reports a sparse set: only the -march tokens it detected, as {token: true}.
    # Unlike x86-64 there is no dense feature list to match (so no "missing" check), and the CPU
    # model is "" for a CPU the detector does not know (see prebuilt/detect_cpu_aarch64.cc).
    if type(report) != "dict":
        return "The CPU feature detector must report a JSON object"
    if type(report.get("cpu")) != "string":
        return "The CPU feature detector must report a string cpu"
    features = report.get("features")
    if type(features) != "dict":
        return "The CPU feature detector's features must be a dictionary"
    unknown = sorted([name for name in features if name not in AARCH64_FEATURES])
    if unknown:
        return "CPU detector features mismatch: unknown [{}]".format(", ".join(unknown))
    for name, value in features.items():
        if type(value) != "bool":
            return "CPU detector feature {} must be a boolean".format(name)
    return None

def aarch64_feature_constraint_names(report):
    """Returns the available constraint name for every feature the detector reports present.

    The aarch64 detector is sparse (it emits only positively detected features), so this returns
    only "_available" names. Undetected features are omitted and fall back to their constraint
    setting's default: unavailable, except the fp/simd baseline. See prebuilt/detect_cpu_aarch64.cc.
    """
    error = _aarch64_report_error(report)
    if error:
        fail(error)
    features = report["features"]
    return sorted([
        name + "_available"
        for name in AARCH64_FEATURES
        if features.get(name)
    ])

validation_for_tests = struct(
    report_error = _report_error,
    aarch64_report_error = _aarch64_report_error,
)
