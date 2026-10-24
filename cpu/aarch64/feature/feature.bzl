load("//private:compat_constraint_setting.bzl", "compat_constraint_setting")

visibility(["//cpu/aarch64/..."])

def aarch64_feature(name, available_by_default = False):
    """Defines feature constraints and the config settings to select() on them.

    Args:
        name: Name of the CPU feature, as spelled in -march.
        available_by_default: Whether an unspecified feature is available.
    """
    available = name + "_available"
    unavailable = name + "_unavailable"
    compat_constraint_setting(
        name = name + "_setting",
        default_constraint_value = available if available_by_default else unavailable,
        # TODO: Refine a prerequisite feature where there is a single canonical one. aarch64
        # implications are a DAG (for example, sme-fa64 requires sme and sve2), which
        # refines_constraint_value cannot express, so every feature refines the CPU constraint.
        refines_constraint_value = "@platforms//cpu:aarch64",
    )
    for config_setting_name, value in [(name, available), ("no_" + name, unavailable)]:
        native.constraint_value(
            name = value,
            constraint_setting = ":" + name + "_setting",
            visibility = ["//visibility:public"],
        )
        native.config_setting(
            name = config_setting_name,
            constraint_values = ["@platforms//cpu:aarch64", ":" + value],
            visibility = ["//visibility:public"],
        )
