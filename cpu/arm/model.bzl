"""The CPU model of Arm platforms that are a specific CPU."""

visibility(["//cpu/arm", "//host", "//private"])

def _arm_model_flag_impl(ctx):
    return [platform_common.TemplateVariableInfo({"ARM_MODEL": ctx.build_setting_value})]

arm_model_flag = rule(
    implementation = _arm_model_flag_impl,
    build_setting = config.string(flag = True),
    attrs = {
        # Read by Bazel 9 and later to decide whether the value propagates to exec configurations.
        "scope": attr.string(),
    },
)

def arm_model_flags(model):
    """Returns the platform flags that declare the CPU model of an Arm platform."""
    return ["--{}={}".format(Label(":model"), model)]
