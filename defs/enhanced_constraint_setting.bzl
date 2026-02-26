visibility(["//..."])

def _enhanced_constraint_setting_impl(name, refines, **kwargs):
    native.config_setting(
        name = name,
        aspect_hints = [refines] if refines else None,
        **kwargs
    )

enhanced_constraint_setting = macro(
    implementation = _enhanced_constraint_setting_impl,
    inherit_attrs = native.config_setting,
    attrs = {
        "refines": attr.label(
            configurable = False,
            mandatory = False,
        ),
        "aspect_hints": None,
    },
)
