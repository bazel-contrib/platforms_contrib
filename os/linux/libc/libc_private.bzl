"""The libc flavor that toolchains should target on Linux platforms."""

load(":libc.bzl", "PreferredLibcInfo", "check_preferred_libc")

visibility(["//os/linux/libc", "//tests"])

LIBC_FLAVORS = [
    "glibc",
    "musl",
]

_FULLY_STATIC_PREFIX = "static-"

# The values of //os/linux/libc:preference: a flavor that the platform has to make available, or a
# flavor to link fully statically, which doesn't depend on the platform's libc.
LIBC_PREFERENCES = LIBC_FLAVORS + [_FULLY_STATIC_PREFIX + flavor for flavor in LIBC_FLAVORS]

_LibcPreferenceInfo = provider(
    doc = "The ranking of libc options set via //os/linux/libc:preference.",
    fields = ["preferences"],
)

def _libc_preference_flag_impl(ctx):
    for preference in ctx.build_setting_value:
        if preference not in LIBC_PREFERENCES:
            fail("Unsupported libc preference {preference} in --{flag}, expected one of: {supported}".format(
                preference = repr(preference),
                flag = ctx.label,
                supported = ", ".join([repr(supported) for supported in LIBC_PREFERENCES]),
            ))
    return [_LibcPreferenceInfo(preferences = ctx.build_setting_value)]

libc_preference_flag = rule(
    implementation = _libc_preference_flag_impl,
    build_setting = config.string_list(flag = True),
    attrs = {
        # Read by Bazel 9 and later to decide whether the value propagates to exec configurations.
        "scope": attr.string(),
    },
)

def _has(ctx, constraint_value):
    return ctx.target_platform_has_constraint(constraint_value[platform_common.ConstraintValueInfo])

def _resolved(flavor, requires_fully_static):
    return PreferredLibcInfo(
        status = "resolved",
        flavor = flavor,
        requires_fully_static = requires_fully_static,
        diagnostic = "",
    )

def _resolve(ctx):
    """Returns the PreferredLibcInfo for the target platform.

    This must never fail for valid rankings: registered toolchains that use the config settings
    derived from it in their `target_settings` are configured for every target platform.
    """
    if not _has(ctx, ctx.attr._linux):
        return PreferredLibcInfo(
            status = "not_applicable",
            flavor = None,
            requires_fully_static = None,
            diagnostic = "",
        )

    preference_flag = ctx.attr._preference
    preferences = preference_flag[_LibcPreferenceInfo].preferences
    available = [
        flavor
        for flavor, constraint_value in zip(LIBC_FLAVORS, ctx.attr._available)
        if _has(ctx, constraint_value)
    ]
    for preference in preferences:
        # Fully static binaries don't depend on the platform's libc.
        if preference.startswith(_FULLY_STATIC_PREFIX):
            return _resolved(preference.removeprefix(_FULLY_STATIC_PREFIX), requires_fully_static = True)
        if preference in available:
            return _resolved(preference, requires_fully_static = False)

    if available:
        reason = "it only declares {} as available".format(" and ".join([repr(flavor) for flavor in available]))
        remedy = "Rank an available flavor or a fully static option such as \"static-musl\"."
    else:
        reason = "it doesn't declare any libc as available"
        remedy = ("Declare the libc of the platform with glibc_version_constraints or " +
                  "musl_version_constraints (e.g. by using {} as the host platform) or rank a fully " +
                  "static option such as \"static-musl\".").format(Label("//host:generic"))
    return PreferredLibcInfo(
        status = "unresolved",
        flavor = None,
        requires_fully_static = None,
        diagnostic = "None of the libc options in --{flag}={preferences} is viable for the target platform {platform} since {reason}. {remedy}".format(
            flag = preference_flag.label,
            preferences = ",".join(preferences),
            platform = ctx.fragments.platform.platform,
            reason = reason,
            remedy = remedy,
        ),
    )

def _preferred_libc_impl(ctx):
    preferred_libc = _resolve(ctx)
    if preferred_libc.status != "resolved":
        flag_value = preferred_libc.status
    elif ctx.attr.requires_fully_static:
        flag_value = str(preferred_libc.requires_fully_static).lower()
    else:
        flag_value = preferred_libc.flavor
    return [
        preferred_libc,
        config_common.FeatureFlagInfo(value = flag_value),
        platform_common.TemplateVariableInfo({
            "PREFERRED_LIBC": preferred_libc.flavor or "",
            "PREFERRED_LIBC_REQUIRES_FULLY_STATIC": "1" if preferred_libc.requires_fully_static else "",
            "PREFERRED_LIBC_STATUS": preferred_libc.status,
        }),
    ]

preferred_libc = rule(
    implementation = _preferred_libc_impl,
    attrs = {
        "requires_fully_static": attr.bool(
            doc = "Whether to provide whether binaries have to be linked fully statically instead " +
                  "of the flavor for `config_setting.flag_values`.",
        ),
        "_available": attr.label_list(default = [
            "//os/linux/libc/{}:available".format(flavor)
            for flavor in LIBC_FLAVORS
        ]),
        "_linux": attr.label(default = "@platforms//os:linux"),
        "_preference": attr.label(default = ":preference"),
    },
    fragments = ["platform"],
)

def _validate_preferred_libc_impl(ctx):
    check_preferred_libc(ctx.attr._preferred[PreferredLibcInfo])
    return []

validate_preferred_libc = rule(
    implementation = _validate_preferred_libc_impl,
    attrs = {
        "_preferred": attr.label(default = ":preferred"),
    },
)
