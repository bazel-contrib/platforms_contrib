"""The libc flavor that toolchains should target on Linux platforms."""

visibility(["//os/linux/libc", "//tests"])

LIBC_FLAVORS = [
    "glibc",
    "musl",
]

_FULLY_STATIC_PREFIX = "static-"

# The values of //os/linux/libc:preference: a flavor to link against the platform's copy of, or a
# flavor to link fully statically, which doesn't depend on the platform's libc.
LIBC_PREFERENCES = LIBC_FLAVORS + [
    _FULLY_STATIC_PREFIX + "musl",
]

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

def _preferred_libc(ctx):
    """Returns the preferred libc flavor and whether it requires linking fully statically."""
    if not _has(ctx, ctx.attr._linux):
        return "", False

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
            return preference.removeprefix(_FULLY_STATIC_PREFIX), True
        if preference in available:
            return preference, False

    if not available:
        fail(("The target platform doesn't make any libc available, so none of the options in " +
              "--{flag}={preferences} is viable. Declare the libc of the platform with " +
              "glibc_version_constraints or musl_version_constraints (e.g. by using {generic} as " +
              "the host platform) or rank a fully static option such as \"static-musl\".").format(
            flag = preference_flag.label,
            preferences = ",".join(preferences),
            generic = Label("//host:generic"),
        ))
    fail("None of the options in --{flag}={preferences} is viable on the target platform, which makes available: {available}".format(
        flag = preference_flag.label,
        preferences = ",".join(preferences),
        available = ", ".join([repr(flavor) for flavor in available]),
    ))

def _preferred_libc_impl(ctx):
    flavor, fully_static = _preferred_libc(ctx)
    return [
        config_common.FeatureFlagInfo(
            value = str(fully_static).lower() if ctx.attr.requires_fully_static else flavor,
        ),
        platform_common.TemplateVariableInfo({
            "PREFERRED_LIBC": flavor,
            "PREFERRED_LIBC_REQUIRES_FULLY_STATIC": "1" if fully_static else "",
        }),
    ]

preferred_libc = rule(
    implementation = _preferred_libc_impl,
    attrs = {
        "requires_fully_static": attr.bool(
            doc = "Whether to provide whether the preferred flavor requires linking fully " +
                  "statically instead of the flavor for `config_setting.flag_values`.",
        ),
        "_available": attr.label_list(default = [
            "//os/linux/libc/{}:available".format(flavor)
            for flavor in LIBC_FLAVORS
        ]),
        "_linux": attr.label(default = "@platforms//os:linux"),
        "_preference": attr.label(default = ":preference"),
    },
)
