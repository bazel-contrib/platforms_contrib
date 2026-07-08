"""Maps the CPU feature names reported by the detect_cpu binary to constraint value names.

The detect_cpu binary (see //prebuilt) reports the enum names used by the cpu_features library
(https://github.com/google/cpu_features), which the constraint values in //cpu/x86_64/feature are
named after. Features that cpu_features cannot report stay at their conservative `no_<feature>`
default, except for a few that are implied by a reported feature. Conversely, if a reportable
feature of the always-available-by-default v1 baseline is missing from the report, its
`no_<feature>` constraint value is set explicitly.
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

# The v1 baseline features that cpu_features can report. Their constraint values are available by
# default, so only their absence has to be mapped, to the `no_<feature>` constraint value. The
# other v1 features (cmov, fxsr, osfxsr, sce) are missing from every report, which says nothing
# about their availability, so they always stay at their available-by-default value.
_X86_64_REPORTABLE_V1_FEATURES = [
    "cx8",
    "fpu",
    "mmx",
    "sse",
    "sse2",
]

# The features whose availability a platform may need to declare explicitly: everything above the
# x86-64-v1 baseline. Reported features not in this list are ignored, either because they are part
# of the v1 baseline handled above or because they deliberately have no constraint value (e.g.
# hle, smx, tsc, and the Xeon Phi-only AVX-512 extensions).
_X86_64_SETTABLE_FEATURES = [
    feature
    for level, features in X86_64_FEATURES.items()
    if level != "v1"
    for feature in features
] + X86_64_FEATURES_WITHOUT_LEVEL

def x86_64_feature_constraint_names(reported_features):
    """Returns the names of the constraint values in //cpu/x86_64/feature matching the host CPU.

    Args:
        reported_features: the list of cpu_features enum names emitted by the detect_cpu binary.

    Returns:
        A sorted list of constraint value names: `<feature>` for each detected feature that is not
        available by default and `no_<feature>` for each v1 baseline feature that is reportable
        but missing from the report.
    """
    available = {}
    for reported in reported_features:
        if reported in _X86_64_SETTABLE_FEATURES:
            available[reported] = None
    for name, required in _X86_64_INFERRED_FEATURES.items():
        if required in reported_features:
            available[name] = None

    # Conservatively drop any feature whose parent feature (per refines_constraint_value) hasn't
    # been detected: a platform must not set a constraint value whose setting refines a constraint
    # value the platform doesn't have.
    names = [
        name
        for name in available
        if _refinement_parents_available(name, available)
    ]

    names += [
        "no_" + feature
        for feature in _X86_64_REPORTABLE_V1_FEATURES
        if feature not in reported_features
    ]

    return sorted(names)

def _refinement_parents_available(name, available):
    parent = X86_64_FEATURE_REFINEMENTS.get(name)
    for _ in range(len(X86_64_FEATURE_REFINEMENTS)):
        if parent == None:
            return True
        if parent not in available:
            return False
        parent = X86_64_FEATURE_REFINEMENTS.get(parent)
    return True
