visibility("private")

GLIBC_VERSIONS = [
    "2." + str(i)
    for i in range(15, 44)
]

def _escape_version(version):
    return "v" + version.replace(".", "_")

def _target_glibc_version_impl(ctx):
    version = ""
    for v in reversed(GLIBC_VERSIONS):
        attr_name = _escape_version(v)
        constraint_value = getattr(ctx.attr, attr_name)[platform_common.ConstraintValueInfo]
        if ctx.target_platform_has_constraint(constraint_value):
            version = v
            break

    return [
        platform_common.TemplateVariableInfo({
            "GLIBC_VERSION": version,
        }),
    ]

target_glibc_version = rule(
    implementation = _target_glibc_version_impl,
    attrs = {
        _escape_version(version): attr.label(default = "//os/linux/libc/glibc:at_least_{}_available".format(version))
        for version in GLIBC_VERSIONS
    },
)
