load("//private:compat_constraint_setting.bzl", "compat_constraint_setting")

visibility(["//cpu/x86_64/..."])

def x86_64_feature(name, available_by_default = False):
    """Defines the constraint setting and values for a single x86-64 CPU feature.

    Creates a `<name>_setting` constraint setting along with the `<name>` and `no_<name>`
    constraint values indicating whether the feature is available on a platform.

    Args:
        name: the name of the feature.
        available_by_default: whether the feature is part of the v1 baseline and thus available on
            every x86-64 platform. Determines the constraint setting's default value.
    """
    compat_constraint_setting(
        name = name + "_setting",
        default_constraint_value = (":" + name) if available_by_default else (":no_" + name),
        refines_constraint_value = "@platforms//cpu:x86_64",
    )
    native.constraint_value(
        name = name,
        constraint_setting = ":" + name + "_setting",
        visibility = ["//visibility:public"],
    )
    native.constraint_value(
        name = "no_" + name,
        constraint_setting = ":" + name + "_setting",
        visibility = ["//visibility:public"],
    )
