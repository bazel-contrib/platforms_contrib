load(":libc_constraints.bzl", "libc_constraints")

def _host_detection_impl(mctx):
    prohibited_users = [module.name for module in mctx.modules if module.name != "platforms_contrib"]
    if prohibited_users:
        fail(
            "platforms_contrib's host detection module extension must not be used by other modules: " +
            ", ".join(prohibited_users),
        )

    libc_constraints(
        name = "libc_constraints",
    )

    return mctx.extension_metadata(
        reproducible = True,
    )

host_detection = module_extension(
    implementation = _host_detection_impl,
)
