"""Maps the CPU feature names reported by the detect_cpu binary to constraint value names.

The detect_cpu binary (see //prebuilt) reports the availability of every enum name used by the
cpu_features library (https://github.com/google/cpu_features), which the constraint values in
//cpu/x86_64/feature are named after. Every reported feature with a constraint value is set
explicitly, as `<feature>` or `no_<feature>`. Features that cpu_features cannot report stay at
their default, except for a few that are implied by a reported feature.

Every name cpu_features can report is accounted for explicitly: a reported feature that is
neither settable, part of the v1 baseline, nor deliberately ignored fails detection.
"""

load(
    "//cpu/x86_64:x86_64_private.bzl",
    "X86_64_FEATURES",
    "X86_64_FEATURES_WITHOUT_LEVEL",
    "X86_64_FEATURE_REFINEMENTS",
)

visibility("private")

# Features that cpu_features does not report but that are implied by another reported feature.
_X86_64_INFERRED_FEATURES = {
    # Every x86-64 CPU that supports SSE4.2 (Nehalem/Bulldozer or later) supports LAHF/SAHF in
    # 64-bit mode.
    "lahf_sahf": "sse4_2",
    # cpu_features only reports AVX if the CPU supports XSAVE and the OS has enabled it.
    "osxsave": "avx",
    "xsave": "avx",
}

# All features modeled as constraint values in //cpu/x86_64/feature.
_X86_64_SETTABLE_FEATURES = [
    feature
    for features in X86_64_FEATURES.values()
    for feature in features
] + X86_64_FEATURES_WITHOUT_LEVEL

# Features that cpu_features (as of 0.11.0) can report but that deliberately have no constraint
# value.
_X86_64_IGNORED_FEATURES = [
    # Present on every x86-64 CPU in practice, but not part of the psABI v1 baseline.
    "clfsh",
    "tsc",
    # CPU implementation details and system-level capabilities with no bearing on code generation.
    "dca",
    "lam",
    "smx",
    "ss",
    "uai",
    # A performance property (the number of 512-bit FMA units), not an ISA capability.
    "avx512_second_fma",
    # Discontinued Xeon Phi-only extensions, removed from LLVM.
    "avx512_4fmaps",
    "avx512_4vbmi2",
    "avx512_4vnniw",
    "avx512er",
    "avx512pf",
    # Deprecated TSX lock elision, disabled by Intel via microcode update.
    "hle",
]

_X86_64_KNOWN_FEATURES = _X86_64_SETTABLE_FEATURES + _X86_64_IGNORED_FEATURES

# The number of features the detect_cpu binary reports, i.e. the number of X86FeaturesEnum values
# in cpu_features 0.11.0. Any other report size indicates a mismatch between the detector binary
# and this mapping or a truncated report.
_X86_64_REPORT_SIZE = 74

def x86_64_feature_constraint_names(reported_features):
    """Returns the names of the constraint values in //cpu/x86_64/feature matching the host CPU.

    Args:
        reported_features: a dict from cpu_features enum name to whether the detect_cpu binary
            reported the feature as available on the host machine.

    Returns:
        A list of constraint value names, one per reported feature with a constraint value:
        `<feature>` if the feature is available and `no_<feature>` if not, with the available
        features sorted first, followed by the sorted unavailable ones.
    """
    unknown_features = [
        feature
        for feature in reported_features
        if feature not in _X86_64_KNOWN_FEATURES
    ]
    if unknown_features:
        fail(
            "The CPU feature detector reported features unknown to feature_mapping.bzl: " +
            ", ".join(unknown_features),
        )
    if len(reported_features) != _X86_64_REPORT_SIZE:
        fail("The CPU feature detector reported {got} features, expected {want}".format(
            got = len(reported_features),
            want = _X86_64_REPORT_SIZE,
        ))

    available = {}
    unavailable = {}
    for reported, is_available in reported_features.items():
        if reported in _X86_64_SETTABLE_FEATURES:
            if is_available:
                available[reported] = None
            else:
                unavailable[reported] = None
    for name, required in _X86_64_INFERRED_FEATURES.items():
        if reported_features.get(required):
            available[name] = None

    for name in available:
        parent = X86_64_FEATURE_REFINEMENTS.get(name)
        if parent != None and parent not in available:
            fail("The CPU feature detector reported {name} as available, but not its parent feature {parent}".format(
                name = name,
                parent = parent,
            ))

    return sorted(available.keys()) + sorted(["no_" + name for name in unavailable])
