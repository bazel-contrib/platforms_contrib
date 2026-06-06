visibility(["//cpu/x86_64/..."])

X86_64_FEATURES = {
    "v1": ["cmov", "cx8", "fpu", "fxsr", "mmx", "osfxsr", "sce", "sse", "sse2"],
    "v2": ["cmpxchg16b", "lahf_sahf", "popcnt", "sse3", "sse4_1", "sse4_2", "ssse3"],
    "v3": ["avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "lzcnt", "movbe", "osxsave"],
    "v4": ["avx512bw", "avx512cd", "avx512dq", "avx512f", "avx512vl"],
}

X86_64_LEVELS = X86_64_FEATURES.keys()

def _features_up_to(level):
    features = []
    for lvl in X86_64_LEVELS:
        features += X86_64_FEATURES[lvl]
        if lvl == level:
            break
    return features

# The features included in each microarchitecture level, including all lower levels.
FEATURES_UP_TO = {level: _features_up_to(level) for level in X86_64_LEVELS}
