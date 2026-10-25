load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("//os/linux/libc/musl:musl.bzl", "musl_version_constraints")

visibility("private")

_PREFERENCE = str(Label("//os/linux/libc:preference"))

_PreferredLibcInfo = provider(
    doc = "The values of the ways to read the preferred libc flavor.",
    fields = ["make_variable", "selected"],
)

def _preferred_libc_subject_impl(ctx):
    return [_PreferredLibcInfo(
        make_variable = ctx.attr.preferred[platform_common.TemplateVariableInfo].variables["PREFERRED_LIBC"],
        selected = ctx.attr.selected,
    )]

_preferred_libc_subject = rule(
    implementation = _preferred_libc_subject_impl,
    attrs = {
        "preferred": attr.label(),
        "selected": attr.string(),
    },
)

def _exec_preferred_libc_impl(ctx):
    return [ctx.attr.preferred[platform_common.TemplateVariableInfo]]

_exec_preferred_libc = rule(
    implementation = _exec_preferred_libc_impl,
    attrs = {"preferred": attr.label(cfg = "exec", default = "//os/linux/libc:preferred")},
)

def _expect_flavor(flavor):
    def impl(env, target):
        info = target[_PreferredLibcInfo]
        env.expect.that_str(info.make_variable).equals(flavor)
        env.expect.that_str(info.selected).equals(flavor)

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
        selected = select({
            "//os/linux/libc:glibc_preferred": "glibc",
            "//os/linux/libc:musl_preferred": "musl",
            "//conditions:default": "",
        }),
    )
    _exec_preferred_libc(name = name + "_exec_subject")

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

    for test, platform, preference, flavor in [
        ("default", "glibc_and_musl", None, "glibc"),
        ("prefer_musl", "glibc_and_musl", ["musl", "glibc"], "musl"),
        ("only_musl", "glibc_and_musl", ["musl"], "musl"),
        # Unavailable flavors are skipped.
        ("glibc_prefer_musl", "glibc", ["musl", "glibc"], "glibc"),
        ("musl_default", "musl", None, "musl"),
        # Without libc constraints, every flavor counts as available.
        ("no_libc_default", "linux", None, "glibc"),
        ("no_libc_prefer_musl", "linux", ["musl", "glibc"], "musl"),
        # The ranking only applies to Linux.
        ("macos", "macos", ["musl"], ""),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = _expect_flavor(flavor),
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
        ("unavailable", "glibc", ["musl"], "None of the libc flavors in --{}=musl is available on the target platform, which has: \"glibc\"".format(Label("//os/linux/libc:preference"))),
        ("empty", "linux", [], "is available on the target platform, which has: none"),
        ("unsupported", "glibc", ["bionic", "glibc"], 'Unsupported libc flavor "bionic" in --{}, expected one of: "glibc", "musl"'.format(Label("//os/linux/libc:preference"))),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = "//os/linux/libc:preferred",
            impl = _expect_failure(message),
            expect_failure = True,
            config_settings = {
                _PREFERENCE: preference,
                "//command_line_option:platforms": str(Label(":{}_{}".format(name, platform))),
            },
        )
