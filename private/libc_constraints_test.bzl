load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//os/linux/libc/glibc:glibc_private.bzl", "GLIBC_VERSIONS")
load("//os/linux/libc/musl:musl_private.bzl", "MUSL_VERSIONS")
load(":libc_constraints.bzl", "parsing_for_tests")

visibility("private")

_GLIBC_MARKER = "release version "
_MUSL_MARKER = "Version "

def _detected_version(text, marker, supported_versions):
    version_key = parsing_for_tests.extract_version_key(text, marker)
    if version_key == None:
        return None
    return parsing_for_tests.floor_to_supported(version_key, supported_versions)

def _glibc_release_banner_test(env):
    env.expect.that_str(_detected_version(
        "\177ELF\002\001ld.so (GNU libc) stable release version 2.35.\n",
        _GLIBC_MARKER,
        GLIBC_VERSIONS,
    )).equals("2.35")

    # Distro builds customize the banner around the version, e.g. Ubuntu's "ld.so (Ubuntu GLIBC
    # 2.39-0ubuntu8.4) stable release version 2.39.".
    env.expect.that_str(_detected_version(
        "garbage\000ld.so (Ubuntu GLIBC 2.39-0ubuntu8.4) stable release version 2.39.\nmore\000",
        _GLIBC_MARKER,
        GLIBC_VERSIONS,
    )).equals("2.39")

def _glibc_snapshot_version_test(env):
    # Development snapshots of glibc use versions such as 2.37.9000.
    env.expect.that_str(_detected_version(
        "stable release version 2.37.9000.\n",
        _GLIBC_MARKER,
        GLIBC_VERSIONS,
    )).equals("2.37")

def _glibc_version_clipping_test(env):
    env.expect.that_str(_detected_version(
        "stable release version 2.52.\n",
        _GLIBC_MARKER,
        GLIBC_VERSIONS,
    )).equals(GLIBC_VERSIONS[-1])

def _glibc_version_below_supported_floor_test(env):
    env.expect.that_bool(
        _detected_version(
            "stable release version 2.10.\n",
            _GLIBC_MARKER,
            GLIBC_VERSIONS,
        ) == None,
    ).equals(True)

def _musl_usage_banner_test(env):
    env.expect.that_str(_detected_version(
        "musl libc (x86_64)\nVersion 1.2.5\nDynamic Program Loader\nUsage: /lib/ld-musl-x86_64.so.1 [options] [--] pathname [args]\n",
        _MUSL_MARKER,
        MUSL_VERSIONS,
    )).equals("1.2")
    env.expect.that_str(_detected_version(
        "musl libc (aarch64)\nVersion 1.1.24\nDynamic Program Loader\n",
        _MUSL_MARKER,
        MUSL_VERSIONS,
    )).equals("1.1")

    # Some distro builds of musl append a suffix to the version.
    env.expect.that_str(_detected_version(
        "musl libc (x86_64)\nVersion 1.2.4-git-1234\n",
        _MUSL_MARKER,
        MUSL_VERSIONS,
    )).equals("1.2")

def _musl_version_clipping_test(env):
    env.expect.that_str(_detected_version(
        "musl libc (x86_64)\nVersion 1.9.0\n",
        _MUSL_MARKER,
        MUSL_VERSIONS,
    )).equals(MUSL_VERSIONS[-1])

def _musl_version_below_supported_floor_test(env):
    env.expect.that_bool(
        _detected_version(
            "musl libc (x86_64)\nVersion 0.9.9\n",
            _MUSL_MARKER,
            MUSL_VERSIONS,
        ) == None,
    ).equals(True)

def _unparseable_version_test(env):
    for text, marker in [
        ("no banner here", _GLIBC_MARKER),
        ("stable release version garbage", _GLIBC_MARKER),
        ("stable release version ", _GLIBC_MARKER),
        ("Version \n", _MUSL_MARKER),
    ]:
        env.expect.that_bool(
            _detected_version(text, marker, GLIBC_VERSIONS) == None,
        ).equals(True)

def libc_constraints_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _glibc_release_banner_test,
            _glibc_snapshot_version_test,
            _glibc_version_clipping_test,
            _glibc_version_below_supported_floor_test,
            _musl_usage_banner_test,
            _musl_version_clipping_test,
            _musl_version_below_supported_floor_test,
            _unparseable_version_test,
        ],
    )
