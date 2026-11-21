load("@apple_support//build_settings:build_settings.bzl", "read_possibly_native_flag")
load(":macos_private.bzl", "MACOS_VERSIONS", "floor_macos_version")

visibility(["//os/macos/version"])

def _escape_version(version):
    return "_v" + version.replace(".", "_")

def _macos_minimum_os(ctx):
    # Bazel 7 doesn't expose the flag to Starlark.
    if "apple" in dir(ctx.fragments) and not hasattr(ctx.fragments.apple, "macos_minimum_os_flag"):
        return None
    return read_possibly_native_flag(ctx, "macos_minimum_os")

def _target_macos_version(ctx):
    if not ctx.target_platform_has_constraint(ctx.attr._macos[platform_common.ConstraintValueInfo]):
        return ""

    minimum_os = _macos_minimum_os(ctx)
    if minimum_os:
        return floor_macos_version(str(minimum_os)) or ""

    for version in reversed(MACOS_VERSIONS):
        constraint_value = getattr(ctx.attr, _escape_version(version))[platform_common.ConstraintValueInfo]
        if ctx.target_platform_has_constraint(constraint_value):
            return version
    return ""

def _target_macos_version_impl(ctx):
    return [
        platform_common.TemplateVariableInfo({
            "MACOS_VERSION": _target_macos_version(ctx),
        }),
    ]

target_macos_version = rule(
    implementation = _target_macos_version_impl,
    attrs = {
        _escape_version(version): attr.label(default = ":at_least_{}_available".format(version))
        for version in MACOS_VERSIONS
    } | {
        "_macos": attr.label(default = "@platforms//os:osx"),
        # Read by read_possibly_native_flag once the flag is no longer built into Bazel.
        "_macos_minimum_os": attr.label(default = "@apple_support//xcode:macos_minimum_os"),
    },
    fragments = ["apple"],
)

def _target_macos_version_at_least_impl(ctx):
    target_version = ctx.attr._target_version[platform_common.TemplateVariableInfo].variables["MACOS_VERSION"]
    at_least = bool(target_version) and MACOS_VERSIONS.index(target_version) >= MACOS_VERSIONS.index(ctx.attr.version)
    return [config_common.FeatureFlagInfo(value = "true" if at_least else "false")]

target_macos_version_at_least = rule(
    implementation = _target_macos_version_at_least_impl,
    attrs = {
        "version": attr.string(mandatory = True, values = MACOS_VERSIONS),
        "_target_version": attr.label(default = ":target_version"),
    },
)
