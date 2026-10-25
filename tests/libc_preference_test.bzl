load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("//os/linux/libc/musl:musl.bzl", "musl_version_constraints")

visibility("private")

_PREFERENCE = str(Label("//os/linux/libc:preference"))

_PreferredLibcInfo = provider(
    doc = "The values of the ways to read the preferred libc.",
    fields = ["make_variables", "selected_flavor", "selected_fully_static"],
)

def _preferred_libc_subject_impl(ctx):
    variables = ctx.attr.preferred[platform_common.TemplateVariableInfo].variables
    return [_PreferredLibcInfo(
        make_variables = [variables["PREFERRED_LIBC"], variables["PREFERRED_LIBC_REQUIRES_FULLY_STATIC"]],
        selected_flavor = ctx.attr.selected_flavor,
        selected_fully_static = ctx.attr.selected_fully_static,
    )]

_preferred_libc_subject = rule(
    implementation = _preferred_libc_subject_impl,
    attrs = {
        "preferred": attr.label(),
        "selected_flavor": attr.string(),
        "selected_fully_static": attr.bool(),
    },
)

def _exec_preferred_libc_impl(ctx):
    return [ctx.attr.preferred[platform_common.TemplateVariableInfo]]

_exec_preferred_libc = rule(
    implementation = _exec_preferred_libc_impl,
    attrs = {"preferred": attr.label(cfg = "exec", default = "//os/linux/libc:preferred")},
)

def _expect_preferred(flavor, fully_static):
    def impl(env, target):
        info = target[_PreferredLibcInfo]
        env.expect.that_collection(info.make_variables).contains_exactly([flavor, "1" if fully_static else ""]).in_order()
        env.expect.that_str(info.selected_flavor).equals(flavor)
        env.expect.that_bool(info.selected_fully_static).equals(fully_static)

    return impl

def _expect_make_variable(flavor):
    def impl(env, target):
        env.expect.that_str(target[platform_common.TemplateVariableInfo].variables["PREFERRED_LIBC"]).equals(flavor)

    return impl

def _expect_failure(message):
    def impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(matching.contains(message))

    return impl

def libc_preference_test_suite(name):
    _preferred_libc_subject(
        name = name + "_subject",
        preferred = "//os/linux/libc:preferred",
        selected_flavor = select({
            "//os/linux/libc:glibc_preferred": "glibc",
            "//os/linux/libc:musl_preferred": "musl",
            "//conditions:default": "",
        }),
        selected_fully_static = select({
            "//os/linux/libc:requires_fully_static": True,
            "//conditions:default": False,
        }),
        tags = ["manual"],
    )
    _exec_preferred_libc(
        name = name + "_exec_subject",
        tags = ["manual"],
    )

    platforms = {
        "linux": [],
        "glibc": glibc_version_constraints("2.35"),
        "musl": musl_version_constraints("1.2"),
        "glibc_and_musl": glibc_version_constraints("2.35") + musl_version_constraints("1.2"),
    }
    for platform, constraints in platforms.items():
        native.platform(
            name = "{}_{}".format(name, platform),
            constraint_values = ["@platforms//cpu:x86_64", "@platforms//os:linux"] + constraints,
        )
    native.platform(
        name = name + "_macos",
        constraint_values = ["@platforms//cpu:aarch64", "@platforms//os:macos"],
    )

    for test, platform, preference, flavor, fully_static in [
        ("default", "glibc_and_musl", None, "glibc", False),
        ("prefer_musl", "glibc_and_musl", ["musl", "glibc"], "musl", False),
        ("only_musl", "glibc_and_musl", ["musl"], "musl", False),
        ("prefer_static_musl", "glibc_and_musl", ["static-musl", "glibc"], "musl", True),
        # Unavailable flavors are skipped, but fully static options are always viable.
        ("glibc_prefer_musl", "glibc", ["musl", "glibc"], "glibc", False),
        ("glibc_static_musl", "glibc", ["static-musl"], "musl", True),
        ("glibc_fallback_static_musl", "glibc", ["glibc", "static-musl"], "glibc", False),
        ("musl_default", "musl", None, "musl", False),
        ("musl_fallback_static_musl", "musl", ["glibc", "static-musl"], "musl", True),
        ("musl_static_glibc", "musl", ["static-glibc"], "glibc", True),
        ("glibc_and_musl_static_glibc", "glibc_and_musl", ["static-glibc", "musl"], "glibc", True),
        # Without libc constraints, only fully static options are viable.
        ("no_libc_static_musl", "linux", ["glibc", "musl", "static-musl"], "musl", True),
        ("no_libc_static_glibc", "linux", ["glibc", "static-glibc", "static-musl"], "glibc", True),
        # The ranking only applies to Linux.
        ("macos", "macos", ["static-musl"], "", False),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = _expect_preferred(flavor, fully_static),
            config_settings = {
                "//command_line_option:platforms": str(Label(":{}_{}".format(name, platform))),
            } | ({_PREFERENCE: preference} if preference != None else {}),
        )

    # Exec configurations use the default ranking.
    analysis_test(
        name = name + "_exec_test",
        target = ":{}_exec_subject".format(name),
        impl = _expect_make_variable("glibc"),
        config_settings = {
            _PREFERENCE: ["musl", "glibc"],
            "//command_line_option:extra_execution_platforms": [str(Label(":{}_glibc_and_musl".format(name)))],
            "//command_line_option:platforms": str(Label(":{}_musl".format(name))),
        },
    )

    for test, platform, preference, message in [
        ("unavailable", "glibc", ["musl"], "None of the options in --{}=musl is viable on the target platform, which makes available: \"glibc\"".format(_PREFERENCE)),
        ("no_libc", "linux", None, "The target platform doesn't make any libc available, so none of the options in --{}=glibc,musl is viable.".format(_PREFERENCE)),
        ("empty", "glibc", [], "None of the options in --{}= is viable".format(_PREFERENCE)),
        ("unsupported", "glibc", ["bionic", "glibc"], 'Unsupported libc preference "bionic" in --{}, expected one of: "glibc", "musl", "static-glibc", "static-musl"'.format(_PREFERENCE)),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = "//os/linux/libc:preferred",
            impl = _expect_failure(message),
            expect_failure = True,
            config_settings = {
                "//command_line_option:platforms": str(Label(":{}_{}".format(name, platform))),
            } | ({_PREFERENCE: preference} if preference != None else {}),
        )
