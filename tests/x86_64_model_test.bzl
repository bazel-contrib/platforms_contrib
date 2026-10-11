load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//private:compat_platform.bzl", "compat_platform")

_MODEL = str(Label("//cpu/x86_64:model"))

def _expect_model(model):
    def impl(env, target):
        env.expect.that_str(target[platform_common.TemplateVariableInfo].variables["X86_64_MODEL"]).equals(model)

    return impl

def _exec_model_impl(ctx):
    return [ctx.attr.model[platform_common.TemplateVariableInfo]]

_exec_model = rule(
    implementation = _exec_model_impl,
    attrs = {"model": attr.label(cfg = "exec", default = "//cpu/x86_64:model")},
)

def x86_64_model_test_suite(name):
    native.platform(name = name + "_x86_64", constraint_values = ["@platforms//cpu:x86_64"])
    compat_platform(
        name = name + "_znver4",
        constraint_values = ["@platforms//cpu:x86_64"],
        flags = ["--{}=znver4".format(_MODEL)],
    )
    _exec_model(name = name + "_exec_model")
    for test, exec_platform, settings, model in [
        # Neither the flag nor the target platform's flags propagate to exec configurations.
        ("exec_flag", ":" + name + "_x86_64", {_MODEL: "znver4"}, ""),
        ("exec_target_platform_flags", ":" + name + "_x86_64", {"//command_line_option:platforms": str(Label(":" + name + "_znver4"))}, ""),
        ("exec_platform_flags", ":" + name + "_znver4", {}, "znver4"),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":" + name + "_exec_model",
            impl = _expect_model(model),
            config_settings = settings | {"//command_line_option:extra_execution_platforms": [str(Label(exec_platform))]},
        )
    for test, platform, settings, model in [
        ("default", ":" + name + "_x86_64", {}, ""),
        ("flag", ":" + name + "_x86_64", {_MODEL: "znver4"}, "znver4"),
        ("platform_flags", ":" + name + "_znver4", {}, "znver4"),
        # :generic resets the flag even if the host is x86-64.
        ("generic_host", "//host:generic", {_MODEL: "znver4"}, ""),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = "//cpu/x86_64:model",
            impl = _expect_model(model),
            config_settings = settings | {"//command_line_option:platforms": str(Label(platform))},
        )
