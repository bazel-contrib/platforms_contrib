visibility("private")

MUSL_VERSIONS = [
    "1." + str(i)
    for i in range(0, 3)
]

def _escape_version(version):
    return "_v" + version.replace(".", "_")

def _target_musl_version_impl(ctx):
    version = ""
    for v in reversed(MUSL_VERSIONS):
        attr_name = _escape_version(v)
        constraint_value = getattr(ctx.attr, attr_name)[platform_common.ConstraintValueInfo]
        if ctx.target_platform_has_constraint(constraint_value):
            version = v
            break

    return [
        platform_common.TemplateVariableInfo({
            "MUSL_VERSION": version,
        }),
    ]

target_musl_version = rule(
    implementation = _target_musl_version_impl,
    attrs = {
        _escape_version(version): attr.label(default = ":at_least_{}_available".format(version))
        for version in MUSL_VERSIONS
    },
)
