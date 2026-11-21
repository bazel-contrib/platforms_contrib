load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//os/macos/version:macos.bzl", "macos_version_constraints")
load("//os/macos/version:macos_private.bzl", "MACOS_VERSIONS", "floor_macos_version")
load("//private:os_version_constraints.bzl", "parsing_for_tests")

visibility("private")

_MACOS_MINIMUM_OS = "//command_line_option:macos_minimum_os"
_HOST_MACOS_MINIMUM_OS = "//command_line_option:host_macos_minimum_os"
_PLATFORMS = "//command_line_option:platforms"
_EXTRA_EXECUTION_PLATFORMS = "//command_line_option:extra_execution_platforms"

def _floor_macos_version_test(env):
    for version, floored in {
        "10.0": "10.0",
        "10.9.5": "10.9",
        "10.15.7": "10.15",
        # Reported by macOS 11 to processes built against older SDKs.
        "10.16": "10.15",
        "11": "11.0",
        "13.3": "13.0",
        "15.7.1": "15.0",
        # Reported by macOS 26 to processes built against older SDKs.
        "16.0": "15.0",
        "26.1": "26.0",
        "99.0": MACOS_VERSIONS[-1],
    }.items():
        env.expect.where(version = version).that_str(floor_macos_version(version)).equals(floored)

def _floor_macos_version_invalid_test(env):
    for version in ["9.6", "", "x.1"]:
        env.expect.where(version = version).that_bool(floor_macos_version(version) == None).equals(True)

def _extract_product_version_test(env):
    env.expect.that_str(parsing_for_tests.extract_product_version("""\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildID</key>
	<string>8F9A3C14-1A2B-11F0-9E5C-1B2C3D4E5F60</string>
	<key>ProductBuildVersion</key>
	<string>25B78</string>
	<key>ProductCopyright</key>
	<string>1983-2025 Apple Inc.</string>
	<key>ProductName</key>
	<string>macOS</string>
	<key>ProductUserVisibleVersion</key>
	<string>26.1</string>
	<key>ProductVersion</key>
	<string>26.1</string>
</dict>
</plist>
""")).equals("26.1")
    for plist in ["", "<key>ProductVersion</key>", "<key>ProductVersion</key><string>26.1"]:
        env.expect.that_bool(parsing_for_tests.extract_product_version(plist) == None).equals(True)

def _macos_version_constraints_test(env):
    env.expect.that_collection([label.name for label in macos_version_constraints("11.0")]).contains_exactly(
        ["at_least_10.{}_available".format(minor) for minor in range(16)] + ["at_least_11.0_available"],
    ).in_order()

def _expect_variable(name, value):
    def impl(env, target):
        env.expect.that_str(target[platform_common.TemplateVariableInfo].variables[name]).equals(value)

    return impl

def _probe_impl(ctx):
    return [platform_common.TemplateVariableInfo({"VALUE": ctx.attr.value})]

_probe = rule(
    implementation = _probe_impl,
    attrs = {"value": attr.string()},
)

def _exec_target_version_impl(ctx):
    return [ctx.attr.target_version[platform_common.TemplateVariableInfo]]

_exec_target_version = rule(
    implementation = _exec_target_version_impl,
    attrs = {"target_version": attr.label(cfg = "exec", default = "//os/macos/version:target_version")},
)

def macos_version_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _floor_macos_version_test,
            _floor_macos_version_invalid_test,
            _extract_product_version_test,
            _macos_version_constraints_test,
        ],
    )

    native.platform(
        name = name + "_macos_14",
        constraint_values = ["@platforms//os:osx"] + macos_version_constraints("14.0"),
    )
    native.platform(
        name = name + "_macos_15",
        constraint_values = ["@platforms//os:osx"] + macos_version_constraints("15.0"),
    )
    native.platform(
        name = name + "_macos_unversioned",
        constraint_values = ["@platforms//os:osx"],
    )
    native.platform(
        name = name + "_linux",
        constraint_values = ["@platforms//os:linux"],
    )

    _probe(
        name = name + "_probe",
        value = select({
            "//os/macos/version:target_at_least_26.0": "26.0",
            "//os/macos/version:target_at_least_14.0": "14.0",
            "//os/macos/version:target_at_least_10.13": "10.13",
            "//conditions:default": "none",
        }),
    )
    _exec_target_version(name = name + "_exec_target_version")

    for test, platform, settings, target_version, selected in [
        ("platform", "_macos_14", {}, "14.0", "14.0"),
        # The flag takes precedence in either direction.
        ("older_flag", "_macos_14", {_MACOS_MINIMUM_OS: "12.3"}, "12.0", "10.13"),
        ("newer_flag", "_macos_14", {_MACOS_MINIMUM_OS: "26.1"}, "26.0", "26.0"),
        ("old_minor_flag", "_macos_14", {_MACOS_MINIMUM_OS: "10.15.7"}, "10.15", "10.13"),
        ("too_old_flag", "_macos_14", {_MACOS_MINIMUM_OS: "9.0"}, "", "none"),
        ("unversioned_platform", "_macos_unversioned", {}, "", "none"),
        ("unversioned_platform_flag", "_macos_unversioned", {_MACOS_MINIMUM_OS: "13.0"}, "13.0", "10.13"),
        # The flag only applies to macOS.
        ("linux_flag", "_linux", {_MACOS_MINIMUM_OS: "13.0"}, "", "none"),
    ]:
        config_settings = settings | {_PLATFORMS: str(Label(":" + name + platform))}
        analysis_test(
            name = "{}_{}_target_version_test".format(name, test),
            target = "//os/macos/version:target_version",
            impl = _expect_variable("MACOS_VERSION", target_version),
            config_settings = config_settings,
        )
        analysis_test(
            name = "{}_{}_select_test".format(name, test),
            target = ":" + name + "_probe",
            impl = _expect_variable("VALUE", selected),
            config_settings = config_settings,
        )

    for test, settings, target_version in [
        ("exec_platform", {}, "15.0"),
        # The target flag doesn't apply to tools.
        ("exec_flag", {_MACOS_MINIMUM_OS: "12.0"}, "15.0"),
        ("exec_host_flag", {_HOST_MACOS_MINIMUM_OS: "13.0"}, "13.0"),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":" + name + "_exec_target_version",
            impl = _expect_variable("MACOS_VERSION", target_version),
            config_settings = settings | {
                _EXTRA_EXECUTION_PLATFORMS: [str(Label(":" + name + "_macos_15"))],
                _PLATFORMS: str(Label(":" + name + "_macos_14")),
            },
        )
