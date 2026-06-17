visibility(["//cpu/x86_64/..."])

X86_64_FEATURES = {
    "v1": ["cmov", "cx8", "fpu", "fxsr", "mmx", "osfxsr", "sce", "sse", "sse2"],
    "v2": ["cmpxchg16b", "lahf_sahf", "popcnt", "sse3", "sse4_1", "sse4_2", "ssse3"],
    "v3": ["avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "lzcnt", "movbe", "osxsave"],
    "v4": ["avx512bw", "avx512cd", "avx512dq", "avx512f", "avx512vl"],
}

X86_64_LEVELS = X86_64_FEATURES.keys()

# Additional CPU features that clang exposes as `-m<feature>` flags but that are not part of any
# x86-64 microarchitecture level (v1-v4). These describe optional hardware capabilities such as
# AES-NI, carry-less multiplication, or AVX-512 extensions beyond the v4 baseline.
#
# The list tracks the feature set defined in current LLVM/clang
# (`llvm/lib/Target/X86/X86.td` together with clang's x86 `-m` driver flags). Names mirror clang's
# feature flags with `.` and `-` replaced by `_` (e.g. clang's `-msse4a`, `-mamx-bf16`, and
# `-mavx10.1-256` become `sse4a`, `amx_bf16`, and `avx10_1_256`). Purely codegen/tuning options that
# do not correspond to a hardware capability (e.g. `retpoline`, `soft-float`, `vzeroupper`) are
# intentionally excluded, as are legacy features no longer supported upstream (e.g. `3dnow`,
# `avx512er`, `avx512pf`, `prefetchwt1`).
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
    "avx10_1_256",
    "avx10_1_512",
    "avx10_2_256",
    "avx10_2_512",
    "avx512bf16",
    "avx512bitalg",
    "avx512fp16",
    "avx512ifma",
    "avx512vbmi",
    "avx512vbmi2",
    "avx512vnni",
    "avx512vp2intersect",
    "avx512vpopcntdq",
    "avxifma",
    "avxneconvert",
    "avxvnni",
    "avxvnniint16",
    "avxvnniint8",
    "cldemote",
    "clflushopt",
    "clwb",
    "clzero",
    "cmpccxadd",
    "crc32",
    "enqcmd",
    "evex512",
    "fma4",
    "fsgsbase",
    "gfni",
    "hreset",
    "invpcid",
    "kl",
    "lwp",
    "movdir64b",
    "movdiri",
    "movrs",
    "mwaitx",
    "pclmul",
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
    "avx512bf16": "avx512f",
    "avx512bitalg": "avx512f",
    "avx512fp16": "avx512f",
    "avx512ifma": "avx512f",
    "avx512vbmi": "avx512f",
    "avx512vbmi2": "avx512f",
    "avx512vnni": "avx512f",
    "avx512vp2intersect": "avx512f",
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
    "vpclmulqdq": "pclmul",
    # Key Locker wide instructions build on Key Locker.
    "widekl": "kl",
    # The AVX10 versions and vector lengths form a chain.
    "avx10_1_512": "avx10_1_256",
    "avx10_2_256": "avx10_1_256",
    "avx10_2_512": "avx10_2_256",
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
