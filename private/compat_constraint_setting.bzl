load("@bazel_features//:features.bzl", "bazel_features")

visibility(["//..."])

def compat_constraint_setting(
        name,
        refines_constraint_value = None,
        **kwargs):
    if bazel_features.rules.constraint_setting_has_refines_constraint_value:
        kwargs = kwargs | {"refines_constraint_value": refines_constraint_value}
    native.constraint_setting(
        name = name,
        **kwargs
    )
