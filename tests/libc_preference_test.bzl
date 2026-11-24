load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//os/linux/libc:libc.bzl", "PreferredLibcInfo", "check_preferred_libc")
load("//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("//os/linux/libc/musl:musl.bzl", "musl_version_constraints")

visibility("private")

_PREFERENCE = str(Label("//os/linux/libc:preference"))

_SubjectInfo = provider(
    doc = "The values of the ways to read the preferred libc.",
    fields = ["provider", "make_variables", "selected"],
)

def _subject_impl(ctx):
    variables = ctx.attr.preferred[platform_common.TemplateVariableInfo].variables
    return [_SubjectInfo(
        provider = ctx.attr.preferred[PreferredLibcInfo],
        make_variables = [
            variables["PREFERRED_LIBC"],
            variables["PREFERRED_LIBC_REQUIRES_FULLY_STATIC"],
            variables["PREFERRED_LIBC_STATUS"],
        ],
        selected = [ctx.attr.selected_flavor, ctx.attr.selected_fully_static, ctx.attr.selected_dynamic],
    )]

_subject = rule(
    implementation = _subject_impl,
    attrs = {
        "preferred": attr.label(),
        "selected_dynamic": attr.bool(),
        "selected_flavor": attr.string(),
        "selected_fully_static": attr.bool(),
    },
)

def _platform_transition_impl(_settings, attr):
    return {"//command_line_option:platforms": str(attr.platform)}

_platform_transition = transition(
    implementation = _platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _transitioned_subject_impl(ctx):
    return [ctx.attr.subject[0][_SubjectInfo]]

_transitioned_subject = rule(
    implementation = _transitioned_subject_impl,
    attrs = {
        "platform": attr.label(),
        "subject": attr.label(cfg = _platform_transition),
    },
)

def _exec_preferred_libc_impl(ctx):
    return [ctx.attr.preferred[platform_common.TemplateVariableInfo]]

_exec_preferred_libc = rule(
    implementation = _exec_preferred_libc_impl,
    attrs = {"preferred": attr.label(cfg = "exec", default = "//os/linux/libc:preferred")},
)

def _toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(kind = ctx.attr.kind)]

_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {"kind": attr.string()},
)

def _error_toolchain_impl(ctx):
    check_preferred_libc(ctx.attr._preferred[PreferredLibcInfo])
    return [platform_common.ToolchainInfo()]

# The pattern documented for toolchains that want to fail with an actionable error.
_error_toolchain = rule(
    implementation = _error_toolchain_impl,
    attrs = {"_preferred": attr.label(default = "//os/linux/libc:preferred")},
)

_ToolchainKindInfo = provider(
    doc = "The kind of the resolved toolchain.",
    fields = ["kind"],
)

def _uses_toolchain(toolchain_type):
    def impl(ctx):
        return [_ToolchainKindInfo(kind = ctx.toolchains[toolchain_type].kind)]

    return rule(implementation = impl, toolchains = [toolchain_type])

_uses_unrelated_toolchain = _uses_toolchain(Label(":libc_preference_unrelated_type"))
_uses_libc_toolchain = _uses_toolchain(Label(":libc_preference_libc_type"))

def _uses_unrelated_toolchain_in_exec_impl(_ctx):
    return []

_uses_unrelated_toolchain_in_exec = rule(
    implementation = _uses_unrelated_toolchain_in_exec_impl,
    attrs = {"tool": attr.label(cfg = "exec")},
)

def _expect_resolved(flavor, fully_static):
    def impl(env, target):
        info = target[_SubjectInfo]
        env.expect.that_str(info.provider.status).equals("resolved")
        env.expect.that_str(info.provider.flavor).equals(flavor)
        env.expect.that_bool(info.provider.requires_fully_static).equals(fully_static)
        env.expect.that_str(info.provider.diagnostic).equals("")
        env.expect.that_collection(info.make_variables).contains_exactly([flavor, "1" if fully_static else "", "resolved"]).in_order()
        env.expect.that_collection(info.selected).contains_exactly([flavor, fully_static, not fully_static]).in_order()

    return impl

def _expect_unresolved(diagnostic):
    def impl(env, target):
        info = target[_SubjectInfo]
        env.expect.that_str(info.provider.status).equals("unresolved")
        env.expect.that_bool(info.provider.flavor == None).equals(True)
        env.expect.that_bool(info.provider.requires_fully_static == None).equals(True)
        env.expect.that_str(info.provider.diagnostic).contains(diagnostic)
        env.expect.that_collection(info.make_variables).contains_exactly(["", "", "unresolved"]).in_order()
        env.expect.that_collection(info.selected).contains_exactly(["unresolved", False, False]).in_order()

    return impl

def _expect_not_applicable(env, target):
    info = target[_SubjectInfo]
    env.expect.that_str(info.provider.status).equals("not_applicable")
    env.expect.that_bool(info.provider.flavor == None).equals(True)
    env.expect.that_bool(info.provider.requires_fully_static == None).equals(True)
    env.expect.that_str(info.provider.diagnostic).equals("")
    env.expect.that_collection(info.make_variables).contains_exactly(["", "", "not_applicable"]).in_order()
    env.expect.that_collection(info.selected).contains_exactly(["", False, False]).in_order()

def _expect_make_variable(flavor):
    def impl(env, target):
        env.expect.that_str(target[platform_common.TemplateVariableInfo].variables["PREFERRED_LIBC"]).equals(flavor)

    return impl

def _expect_success(_env, _target):
    pass

def _expect_toolchain(kind):
    def impl(env, target):
        env.expect.that_str(target[_ToolchainKindInfo].kind).equals(kind)

    return impl

def _expect_failure(message):
    def impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(matching.contains(message))

    return impl

def _platform_settings(name, platform, preference = None):
    return {
        "//command_line_option:platforms": str(Label(":{}_{}".format(name, platform))),
    } | ({_PREFERENCE: preference} if preference != None else {})

def libc_preference_test_suite(name):
    _subject(
        name = name + "_subject",
        preferred = "//os/linux/libc:preferred",
        selected_flavor = select({
            "//os/linux/libc:glibc_preferred": "glibc",
            "//os/linux/libc:musl_preferred": "musl",
            "//os/linux/libc:unresolved": "unresolved",
            "//conditions:default": "",
        }),
        selected_fully_static = select({
            "//os/linux/libc:requires_fully_static": True,
            "//conditions:default": False,
        }),
        selected_dynamic = select({
            "//os/linux/libc:allows_dynamic": True,
            "//conditions:default": False,
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

    for test, platform, preference, flavor, fully_static in [
        ("default", "glibc_and_musl", None, "glibc", False),
        ("prefer_musl", "glibc_and_musl", ["musl", "glibc"], "musl", False),
        ("only_musl", "glibc_and_musl", ["musl"], "musl", False),
        ("prefer_static_musl", "glibc_and_musl", ["static-musl", "glibc"], "musl", True),
        ("prefer_static_glibc", "glibc_and_musl", ["static-glibc", "musl"], "glibc", True),
        # Flavors that the platform doesn't declare are skipped, but fully static options are
        # always viable.
        ("glibc_prefer_musl", "glibc", ["musl", "glibc"], "glibc", False),
        ("glibc_static_musl", "glibc", ["static-musl"], "musl", True),
        ("glibc_fallback_static_musl", "glibc", ["glibc", "static-musl"], "glibc", False),
        ("musl_default", "musl", None, "musl", False),
        ("musl_fallback_static_musl", "musl", ["glibc", "static-musl"], "musl", True),
        ("musl_static_glibc", "musl", ["static-glibc"], "glibc", True),
        # Without libc constraints, only fully static options are viable.
        ("no_libc_static_musl", "linux", ["glibc", "musl", "static-musl"], "musl", True),
        ("no_libc_static_glibc", "linux", ["glibc", "static-glibc", "static-musl"], "glibc", True),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = _expect_resolved(flavor, fully_static),
            config_settings = _platform_settings(name, platform, preference),
        )

    for test, platform, preference, diagnostic in [
        ("unavailable", "glibc", ["musl"], "None of the libc options in --{}=musl is viable for the target platform {} since it only declares \"glibc\" as available.".format(_PREFERENCE, Label(":{}_glibc".format(name)))),
        ("no_libc", "linux", None, "None of the libc options in --{}=glibc,musl is viable for the target platform {} since it doesn't declare any libc as available.".format(_PREFERENCE, Label(":{}_linux".format(name)))),
        ("empty", "glibc_and_musl", [], "since it only declares \"glibc\" and \"musl\" as available."),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = _expect_unresolved(diagnostic),
            config_settings = _platform_settings(name, platform, preference),
        )

    # The preference is resolved again after a transition changes the target platform.
    _transitioned_subject(
        name = name + "_musl_subject",
        platform = ":{}_musl".format(name),
        subject = ":{}_subject".format(name),
    )
    analysis_test(
        name = name + "_platform_transition_test",
        target = ":{}_musl_subject".format(name),
        impl = _expect_resolved("musl", False),
        config_settings = _platform_settings(name, "glibc"),
    )

    # The ranking only applies to Linux.
    analysis_test(
        name = name + "_macos_test",
        target = ":{}_subject".format(name),
        impl = _expect_not_applicable,
        config_settings = _platform_settings(name, "macos", ["static-musl"]),
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

    # Toolchains that use the config settings in `target_settings` are configured for every target
    # platform, even when resolving an unrelated toolchain type, so resolving the preference must
    # not fail for platforms without a viable option.
    native.toolchain_type(name = name + "_unrelated_type")
    native.toolchain_type(name = name + "_libc_type")
    for kind in ["unrelated", "glibc", "static_musl"]:
        _toolchain(
            name = "{}_{}_toolchain_impl".format(name, kind),
            kind = kind,
        )
    _error_toolchain(
        name = name + "_error_toolchain_impl",
        # Fails if built directly for a platform without a viable option.
        tags = ["manual"],
    )
    native.toolchain(
        name = name + "_unrelated_toolchain",
        toolchain = ":{}_unrelated_toolchain_impl".format(name),
        toolchain_type = ":{}_unrelated_type".format(name),
    )
    native.toolchain(
        name = name + "_glibc_toolchain",
        target_settings = [
            "//os/linux/libc:glibc_preferred",
            "//os/linux/libc:allows_dynamic",
        ],
        toolchain = ":{}_glibc_toolchain_impl".format(name),
        toolchain_type = ":{}_libc_type".format(name),
    )

    # A toolchain that only supports fully static musl also satisfies a bare "musl".
    native.toolchain(
        name = name + "_static_musl_toolchain",
        target_settings = ["//os/linux/libc:musl_preferred"],
        toolchain = ":{}_static_musl_toolchain_impl".format(name),
        toolchain_type = ":{}_libc_type".format(name),
    )
    native.toolchain(
        name = name + "_error_toolchain",
        target_settings = ["//os/linux/libc:unresolved"],
        toolchain = ":{}_error_toolchain_impl".format(name),
        toolchain_type = ":{}_libc_type".format(name),
    )
    toolchains = [
        str(Label(":{}_{}".format(name, toolchain)))
        for toolchain in ["unrelated_toolchain", "glibc_toolchain", "static_musl_toolchain", "error_toolchain"]
    ]

    # The toolchains are only registered by the tests.
    _uses_unrelated_toolchain(
        name = name + "_uses_unrelated_toolchain",
        tags = ["manual"],
    )
    _uses_unrelated_toolchain_in_exec(
        name = name + "_uses_unrelated_toolchain_in_exec",
        tool = ":{}_uses_unrelated_toolchain".format(name),
        tags = ["manual"],
    )
    _uses_libc_toolchain(
        name = name + "_uses_libc_toolchain",
        tags = ["manual"],
    )

    for test, target, settings, impl in [
        ("unrelated_toolchain", "uses_unrelated_toolchain", _platform_settings(name, "linux"), _expect_toolchain("unrelated")),
        ("unrelated_toolchain_in_exec", "uses_unrelated_toolchain_in_exec", {
            "//command_line_option:extra_execution_platforms": [str(Label(":{}_linux".format(name)))],
        }, _expect_success),
        ("libc_toolchain_glibc", "uses_libc_toolchain", _platform_settings(name, "glibc"), _expect_toolchain("glibc")),
        ("libc_toolchain_bare_musl", "uses_libc_toolchain", _platform_settings(name, "musl", ["musl"]), _expect_toolchain("static_musl")),
        ("libc_toolchain_static_musl", "uses_libc_toolchain", _platform_settings(name, "linux", ["static-musl"]), _expect_toolchain("static_musl")),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_{}".format(name, target),
            impl = impl,
            config_settings = settings | {"//command_line_option:extra_toolchains": toolchains},
        )

    for test, platform, preference, impl in [
        ("validate_resolved", "glibc", None, _expect_success),
        ("validate_unresolved", "glibc", ["musl"], _expect_failure("since it only declares \"glibc\" as available. Rank an available flavor or a fully static option such as \"static-musl\".")),
        ("validate_not_applicable", "macos", None, _expect_success),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = "//os/linux/libc:validate_preference",
            impl = impl,
            expect_failure = impl != _expect_success,
            config_settings = _platform_settings(name, platform, preference),
        )

    analysis_test(
        name = name + "_unsupported_test",
        target = "//os/linux/libc:preferred",
        impl = _expect_failure('Unsupported libc preference "bionic" in --{}, expected one of: "glibc", "musl", "static-glibc", "static-musl"'.format(_PREFERENCE)),
        expect_failure = True,
        config_settings = _platform_settings(name, "glibc", ["bionic", "glibc"]),
    )
