visibility(["//os/macos/version", "//private", "//tests"])

# Up to macOS 10.15, each yearly release increased the minor version. Starting with macOS 11, it
# increases the major version and minor versions are mid-year updates, so only major versions are
# listed, matching Python wheel tags. Apple skipped from 15 to 26 in 2025 to match the year.
MACOS_VERSIONS = [
    "10." + str(minor)
    for minor in range(16)
] + [
    str(major) + ".0"
    for major in list(range(11, 16)) + list(range(26, 29))
]

def _version_key(version):
    major, _, minor = version.partition(".")
    return (int(major), int(minor))

def floor_macos_version(version):
    """Returns the newest version in MACOS_VERSIONS not newer than the given dotted version.

    Returns None if the version can't be parsed or is older than all of them.
    """
    components = version.split(".")
    if not components[0].isdigit():
        return None
    major = int(components[0])
    minor = int(components[1]) if len(components) > 1 and components[1].isdigit() else 0
    if major >= 11:
        minor = 0
    for supported in reversed(MACOS_VERSIONS):
        if _version_key(supported) <= (major, minor):
            return supported
    return None
