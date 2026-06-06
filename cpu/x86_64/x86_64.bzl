load(":x86_64_private.bzl", "FEATURES_UP_TO")

def x86_64_level_constraints(level):
    """Returns the constraints describing the given x86-64 microarchitecture level available on a platform."""
    if level not in FEATURES_UP_TO:
        fail("Unsupported x86-64 microarchitecture level: {level}".format(level = level))
    return [
        Label("//cpu/x86_64/feature/{feature}:available".format(feature = feature))
        for feature in FEATURES_UP_TO[level]
    ]
