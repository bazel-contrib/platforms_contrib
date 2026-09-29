"""Maps detect_cpu output to //cpu/x86_64/feature constraint names.

The detector (//prebuilt) reports cpu_features names (https://github.com/google/cpu_features).
Each feature with a constraint becomes `<feature>` or `no_<feature>`. Unreported features keep
their defaults unless implied by an available feature.

Unknown feature names fail detection; known names are mapped to constraints or explicitly ignored.
"""

load(
    "//cpu/x86_64:x86_64_private.bzl",
    "X86_64_FEATURES",
    "X86_64_FEATURES_WITHOUT_LEVEL",
    "X86_64_FEATURE_REFINEMENTS",
)

visibility("private")

# Unreported features implied by available features.
_X86_64_INFERRED_FEATURES = {
    # x86-64 CPUs with SSE4.2 also support LAHF/SAHF in 64-bit mode.
    "lahf_sahf": "sse4_2",
    # cpu_features only reports AVX if the CPU supports XSAVE and the OS has enabled it.
    "osxsave": "avx",
    "xsave": "avx",
}

# Features with constraints in //cpu/x86_64/feature.
_X86_64_SETTABLE_FEATURES = [
    feature
    for features in X86_64_FEATURES.values()
    for feature in features
] + X86_64_FEATURES_WITHOUT_LEVEL

# Features reported by cpu_features 0.11.0 but deliberately omitted from constraints.
_X86_64_IGNORED_FEATURES = [
    # Present on every x86-64 CPU in practice, but not part of the psABI v1 baseline.
    "clfsh",
    "tsc",
    # Implementation details and system capabilities that don't affect code generation.
    "dca",
    "lam",
    "smx",
    "ss",
    "uai",
    # Number of 512-bit FMA units; affects performance, not instruction availability.
    "avx512_second_fma",
    # Discontinued Xeon Phi-only extensions, removed from LLVM.
    "avx512_4fmaps",
    "avx512_4vbmi2",
    "avx512_4vnniw",
    "avx512er",
    "avx512pf",
    # Deprecated TSX lock elision, disabled by Intel microcode.
    "hle",
]

_X86_64_KNOWN_FEATURES = _X86_64_SETTABLE_FEATURES + _X86_64_IGNORED_FEATURES

# Expected feature count from cpu_features 0.11.0. Reject other sizes to catch detector version
# mismatches and truncated output.
_X86_64_REPORT_SIZE = 74

def x86_64_feature_constraint_names(reported_features):
    """Returns the host CPU's constraint value names in //cpu/x86_64/feature.

    Args:
        reported_features: Dict mapping cpu_features names to availability booleans.

    Returns:
        Sorted available names (including inferred features), followed by sorted
        `no_<feature>` names for unavailable features with constraints.
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
