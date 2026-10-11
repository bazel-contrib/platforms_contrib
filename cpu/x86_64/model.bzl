"""The CPU model of x86-64 platforms that are a specific CPU."""

visibility(["//cpu/x86_64", "//host", "//private"])

def _x86_64_model_flag_impl(ctx):
    return [platform_common.TemplateVariableInfo({"X86_64_MODEL": ctx.build_setting_value})]

x86_64_model_flag = rule(
    implementation = _x86_64_model_flag_impl,
    build_setting = config.string(flag = True),
    attrs = {
        # Read by Bazel 9 and later to decide whether the value propagates to exec configurations.
        "scope": attr.string(),
    },
)

def x86_64_model_flags(model):
    """Returns the platform flags that declare the CPU model of an x86-64 platform."""
    return ["--{}={}".format(Label(":model"), model)]
