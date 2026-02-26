visibility(["//..."])

def _enhanced_constraint_setting_impl(name, refines, **kwargs):
    native.constraint_setting(
        name = name,
        aspect_hints = [refines] if refines else None,
        **kwargs
    )

enhanced_constraint_setting = macro(
    implementation = _enhanced_constraint_setting_impl,
    inherit_attrs = native.constraint_setting,
    attrs = {
        "refines": attr.label(
            configurable = False,
            mandatory = False,
        ),
        "aspect_hints": None,
    },
)
