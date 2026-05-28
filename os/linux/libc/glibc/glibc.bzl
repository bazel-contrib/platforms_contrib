load(":glibc_private.bzl", "GLIBC_VERSIONS")

def glibc_version_constraints(version):
    if version not in GLIBC_VERSIONS:
        fail("Unsupported glibc version: {version}".format(version = version))
    return [
        Label("//os/linux/libc/glibc:at_least_{version}_available".format(version = lower_version))
        for lower_version in GLIBC_VERSIONS[:GLIBC_VERSIONS.index(version) + 1]
    ]
