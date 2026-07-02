"""Maps the CPU feature names reported by detect_cpu.c to constraint value names.

detect_cpu.c reports the enum names used by the cpu_features library
(https://github.com/google/cpu_features), which the constraint values in //cpu/x86_64/feature are
named after. Features that cpu_features cannot report stay at their conservative `no_<feature>`
default, except for a few that are implied by a reported feature.
"""

load("//cpu/x86_64:x86_64_private.bzl", "X86_64_FEATURE_REFINEMENTS")

visibility(["//host/..."])

# The x86-64 features reported by cpu_features that have a corresponding constraint value in
# //cpu/x86_64/feature. Features that are part of the x86-64-v1 baseline are not listed since
# their constraint values are available by default on every x86-64 platform.
_X86_64_DETECTABLE_FEATURES = [
    "adx",
    "aes",
    "amx_bf16",
    "amx_fp16",
    "amx_int8",
    "amx_tile",
    "avx",
    "avx2",
    "avx512_bf16",
    "avx512_fp16",
    "avx512_vp2intersect",
    "avx512bitalg",
    "avx512bw",
    "avx512cd",
    "avx512dq",
    "avx512f",
    "avx512ifma",
    "avx512vbmi",
    "avx512vbmi2",
    "avx512vl",
    "avx512vnni",
    "avx512vpopcntdq",
    "avx_vnni",
    "bmi1",
    "bmi2",
    "clflushopt",
    "clwb",
    "cx16",
    "erms",
    "f16c",
    "fma3",
    "fma4",
    "fs_rep_cmpsb_scasb",
    "fs_rep_mov",
    "fs_rep_stosb",
    "fz_rep_movsb",
    "gfni",
    "lzcnt",
    "movbe",
    "movdir64b",
    "movdiri",
    "pclmulqdq",
    "popcnt",
    "rdrnd",
    "rdseed",
    "rtm",
    "sgx",
    "sha",
    "sse3",
    "sse4_1",
    "sse4_2",
    "sse4a",
    "ssse3",
    "vaes",
    "vpclmulqdq",
]

# Features that cpu_features does not report but that are implied by another reported feature.
_X86_64_INFERRED_FEATURES = {
    # Every x86-64 CPU that supports SSE4.2 (Nehalem/Bulldozer or later) supports LAHF/SAHF in
    # 64-bit mode.
    "lahf_sahf": "sse4_2",
    # cpu_features only reports AVX if the CPU supports XSAVE and the OS has enabled it.
    "osxsave": "avx",
    "xsave": "avx",
}

def x86_64_feature_constraint_names(reported_features):
    """Returns the names of the constraint values in //cpu/x86_64/feature matching the host CPU.

    Args:
        reported_features: the list of cpu_features enum names emitted by detect_cpu.c.

    Returns:
        A sorted list of constraint value names, restricted to features that are not available by
        default.
    """
    available = {}
    for reported in reported_features:
        if reported in _X86_64_DETECTABLE_FEATURES:
            available[reported] = None
    for name, required in _X86_64_INFERRED_FEATURES.items():
        if required in reported_features:
            available[name] = None

    # Conservatively drop any feature whose parent feature (per refines_constraint_value) hasn't
    # been detected: a platform must not set a constraint value whose setting refines a constraint
    # value the platform doesn't have.
    return sorted([
        name
        for name in available
        if _refinement_parents_available(name, available)
    ])

def _refinement_parents_available(name, available):
    parent = X86_64_FEATURE_REFINEMENTS.get(name)
    for _ in range(len(X86_64_FEATURE_REFINEMENTS)):
        if parent == None:
            return True
        if parent not in available:
            return False
        parent = X86_64_FEATURE_REFINEMENTS.get(parent)
    return True
