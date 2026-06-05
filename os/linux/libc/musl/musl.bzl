load(":musl_private.bzl", "MUSL_VERSIONS")

def musl_version_constraints(version):
    """Returns the constraints describing the given musl version available on a platform."""
    if version not in MUSL_VERSIONS:
        fail("Unsupported musl version: {version}".format(version = version))
    return [
        Label(":at_least_{version}_available".format(version = lower_version))
        for lower_version in MUSL_VERSIONS[:MUSL_VERSIONS.index(version) + 1]
    ]
