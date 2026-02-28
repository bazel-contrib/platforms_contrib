# Aspects don't propagate to non-configurable rules such as constraint_value, so we have to emulate the "refines"
# behavior.

_REFINES = {
    Label("//libc/glibc:version"): Label("//libc:glibc"),
}

def _interpose(list, separator):
    return [s for v in list for s in (v, separator)][:-1]

def _validate_platforms_aspect_impl(target, ctx):
    if ctx.rule.kind != "platform":
        return []
    seen = set()
    required = set()
    constraint_collection = target[platform_common.PlatformInfo].constraints
    for constraint_setting in constraint_collection.constraint_settings:
        constraint_value = constraint_collection.get(constraint_setting)
        seen.add(constraint_value.label)
        refines = _REFINES.get(constraint_value.constraint.label)
        if refines:
            required.add(refines)
    missing = list(required - seen)
    if missing:
        fail_args = [
            "Platform ",
            target.label,
            " is missing implied constraint values: ",
        ] + _interpose(missing, ", ") + ["\n\n  buildozer 'add constraint_values "] + _interpose(missing, " ") + ["' ", target.label, "\n\n"]
        fail(sep = "", *fail_args)
    return []

validate_platforms_aspect = aspect(
    implementation = _validate_platforms_aspect_impl,
    required_providers = [platform_common.PlatformInfo],
)
