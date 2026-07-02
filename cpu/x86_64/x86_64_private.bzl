visibility([
    "//cpu/x86_64/...",
    # For the mapping of detected CPU features to constraint values.
    "//host/...",
])

X86_64_FEATURES = {
    "v1": ["cmov", "cx8", "fpu", "fxsr", "mmx", "osfxsr", "sce", "sse", "sse2"],
    "v2": ["cx16", "lahf_sahf", "popcnt", "sse3", "sse4_1", "sse4_2", "ssse3"],
    "v3": ["avx", "avx2", "bmi1", "bmi2", "f16c", "fma3", "lzcnt", "movbe", "osxsave"],
    "v4": ["avx512bw", "avx512cd", "avx512dq", "avx512f", "avx512vl"],
}

X86_64_LEVELS = X86_64_FEATURES.keys()

# Additional CPU features that are not part of any x86-64 microarchitecture level (v1-v4). These
# describe optional hardware capabilities such as AES-NI, carry-less multiplication, or AVX-512
# extensions beyond the v4 baseline.
#
# The list tracks CPUID hardware capabilities, first and foremost those reported by the
# cpu_features library (https://github.com/google/cpu_features), whose names are also used for
# the constraint values so that features detected on the host (see //host) map to constraint
# values directly. Capabilities not (yet) covered by cpu_features use their common lowercase name
# with `.` and `-` replaced by `_` (e.g. `amx_bf16`, `avx10_1`).
#
# Compiler options that do not correspond to a dedicated hardware capability are intentionally
# excluded: purely codegen/tuning options (e.g. `retpoline`, `soft-float`, `vzeroupper`,
# `evex512`), features without their own CPUID bit (e.g. `crc32`, which is part of SSE4.2), and
# legacy features no longer supported by current hardware and toolchains (e.g. `3dnow`,
# `avx512er`, `avx512pf`, `prefetchwt1`). The AVX10 constraints follow the revised AVX10
# specification, which dropped the 256-/512-bit vector length split: `avx10_1` and `avx10_2`
# always include 512-bit vectors.
X86_64_FEATURES_WITHOUT_LEVEL = [
    "adx",
    "aes",
    "amx_avx512",
    "amx_bf16",
    "amx_complex",
    "amx_fp16",
    "amx_int8",
    "amx_tf32",
    "amx_tile",
    "apxf",
    "avx10_1",
    "avx10_2",
    "avx512_bf16",
    "avx512_fp16",
    "avx512_vp2intersect",
    "avx512bitalg",
    "avx512ifma",
    "avx512vbmi",
    "avx512vbmi2",
    "avx512vnni",
    "avx512vpopcntdq",
    "avx_vnni",
    "avxifma",
    "avxneconvert",
    "avxvnniint16",
    "avxvnniint8",
    "cldemote",
    "clflushopt",
    "clwb",
    "clzero",
    "cmpccxadd",
    "enqcmd",
    "erms",
    "fma4",
    "fs_rep_cmpsb_scasb",
    "fs_rep_mov",
    "fs_rep_stosb",
    "fsgsbase",
    "fz_rep_movsb",
    "gfni",
    "hreset",
    "invpcid",
    "kl",
    "lwp",
    "movdir64b",
    "movdiri",
    "movrs",
    "mwaitx",
    "pclmulqdq",
    "pconfig",
    "pku",
    "prefetchi",
    "prfchw",
    "ptwrite",
    "raoint",
    "rdpid",
    "rdpru",
    "rdrnd",
    "rdseed",
    "rtm",
    "serialize",
    "sgx",
    "sha",
    "sha512",
    "shstk",
    "sm3",
    "sm4",
    "sse4a",
    "tbm",
    "tsxldtrk",
    "uintr",
    "usermsr",
    "vaes",
    "vpclmulqdq",
    "waitpkg",
    "wbnoinvd",
    "widekl",
    "xop",
    "xsave",
    "xsavec",
    "xsaveopt",
    "xsaves",
]

# Maps a feature to another feature that it extends. The feature's constraint setting refines the
# parent feature's `available` constraint value, expressing that the feature can only be present on a
# platform that also has the parent. For example, the AVX-512 extensions require AVX-512 Foundation
# (avx512f), and the wider/vectorized variants of AES and carry-less multiplication build on their
# scalar counterparts. Features not listed here refine `@platforms//cpu:x86_64` and are otherwise
# independent.
X86_64_FEATURE_REFINEMENTS = {
    # AVX-512 extensions beyond the v4 baseline all build on AVX-512 Foundation.
    "avx512_bf16": "avx512f",
    "avx512_fp16": "avx512f",
    "avx512_vp2intersect": "avx512f",
    "avx512bitalg": "avx512f",
    "avx512ifma": "avx512f",
    "avx512vbmi": "avx512f",
    "avx512vbmi2": "avx512f",
    "avx512vnni": "avx512f",
    "avx512vpopcntdq": "avx512f",
    # AMX extensions build on the AMX tile architecture.
    "amx_bf16": "amx_tile",
    "amx_complex": "amx_tile",
    "amx_fp16": "amx_tile",
    "amx_int8": "amx_tile",
    "amx_avx512": "amx_tile",
    "amx_tf32": "amx_tile",
    # The extended xsave instructions build on the base xsave feature.
    "xsavec": "xsave",
    "xsaveopt": "xsave",
    "xsaves": "xsave",
    # Vectorized variants build on their scalar counterparts.
    "vaes": "aes",
    "vpclmulqdq": "pclmulqdq",
    # Key Locker wide instructions build on Key Locker.
    "widekl": "kl",
    # The AVX10 versions form a chain.
    "avx10_2": "avx10_1",
}

def _features_up_to(level):
    features = []
    for lvl in X86_64_LEVELS:
        features += X86_64_FEATURES[lvl]
        if lvl == level:
            break
    return features

# The features included in each microarchitecture level, including all lower levels.
FEATURES_UP_TO = {level: _features_up_to(level) for level in X86_64_LEVELS}
