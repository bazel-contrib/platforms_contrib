load(":macos_private.bzl", "MACOS_VERSIONS")

def macos_version_constraints(version):
    """Returns the constraints describing a platform that runs the given macOS version or later."""
    if version not in MACOS_VERSIONS:
        fail("Unsupported macOS version {version}, expected one of: {supported}".format(
            version = repr(version),
            supported = ", ".join([repr(supported) for supported in MACOS_VERSIONS]),
        ))
    return [
        Label(":at_least_{version}_available".format(version = lower_version))
        for lower_version in MACOS_VERSIONS[:MACOS_VERSIONS.index(version) + 1]
    ]
