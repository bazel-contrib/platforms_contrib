load(":x86_64_private.bzl", "FEATURES_UP_TO", "X86_64_LEVELS")

def x86_64_level_constraints(level):
    """Returns the constraints describing the given x86-64 microarchitecture level available on a platform."""
    if level not in FEATURES_UP_TO:
        fail("Unsupported x86-64 microarchitecture level {level}, expected one of: {supported}".format(
            level = repr(level),
            supported = ", ".join([repr(supported) for supported in X86_64_LEVELS]),
        ))
    return [
        Label("//cpu/x86_64/feature:{feature}_available".format(feature = feature))
        for feature in FEATURES_UP_TO[level]
    ]
