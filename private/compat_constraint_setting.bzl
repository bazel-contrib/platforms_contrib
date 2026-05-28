visibility(["//..."])

def compat_constraint_setting(
        name,
        # TODO: Unused until supported by Bazel.
        refines_constraint_value = None,  # buildifier: disable=unused-variable
        **kwargs):
    native.constraint_setting(
        name = name,
        **kwargs
    )
