visibility(["//..."])

def _enhanced_constraint_setting_impl(name, refines_value, **kwargs):
    # Note: refines_value is ignored here and the refines within this repo are instead listed manually in
    # validate_platforms_aspect.bzl. This is because aspects don't propagate through a platform's constraint_values
    # attribute and thus can't read any of metadata that could be attached here.
    native.constraint_setting(
        name = name,
        **kwargs
    )

enhanced_constraint_setting = macro(
    implementation = _enhanced_constraint_setting_impl,
    inherit_attrs = native.constraint_setting,
    attrs = {
        "refines_value": attr.label(
            configurable = False,
            mandatory = False,
        ),
    },
)
