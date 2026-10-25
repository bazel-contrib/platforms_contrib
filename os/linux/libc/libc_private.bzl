"""The libc flavor that toolchains should target on Linux platforms."""

visibility(["//os/linux/libc", "//tests"])

LIBC_FLAVORS = [
    "glibc",
    "musl",
]

_LibcPreferenceInfo = provider(
    doc = "The ranking of libc flavors set via //os/linux/libc:preference.",
    fields = ["flavors"],
)

def _libc_preference_flag_impl(ctx):
    for flavor in ctx.build_setting_value:
        if flavor not in LIBC_FLAVORS:
            fail("Unsupported libc flavor {flavor} in --{flag}, expected one of: {supported}".format(
                flavor = repr(flavor),
                flag = ctx.label,
                supported = ", ".join([repr(supported) for supported in LIBC_FLAVORS]),
            ))
    return [_LibcPreferenceInfo(flavors = ctx.build_setting_value)]

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

def _preferred_libc_flavor(ctx):
    if not _has(ctx, ctx.attr._linux):
        return ""

    preference = ctx.attr._preference[_LibcPreferenceInfo].flavors
    available = [
        flavor
        for flavor, constraint_value in zip(LIBC_FLAVORS, ctx.attr._available)
        if _has(ctx, constraint_value)
    ]
    for flavor in preference:
        # Platforms without libc constraints don't restrict the flavor.
        if not available or flavor in available:
            return flavor
    fail("None of the libc flavors in --{flag}={preference} is available on the target platform, which has: {available}".format(
        flag = ctx.attr._preference.label,
        preference = ",".join(preference),
        available = ", ".join([repr(flavor) for flavor in available]) or "none",
    ))

def _preferred_libc_impl(ctx):
    flavor = _preferred_libc_flavor(ctx)
    return [
        config_common.FeatureFlagInfo(value = flavor),
        platform_common.TemplateVariableInfo({"PREFERRED_LIBC": flavor}),
    ]

preferred_libc = rule(
    implementation = _preferred_libc_impl,
    attrs = {
        "_available": attr.label_list(default = [
            "//os/linux/libc/{}:available".format(flavor)
            for flavor in LIBC_FLAVORS
        ]),
        "_linux": attr.label(default = "@platforms//os:linux"),
        "_preference": attr.label(default = ":preference"),
    },
)
