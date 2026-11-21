load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//os/macos/version:macos_private.bzl", "floor_macos_version")

visibility(["//private", "//tests"])

_SYSTEM_VERSION_PLIST = "/System/Library/CoreServices/SystemVersion.plist"

def _extract_product_version(plist):
    _, found, rest = plist.partition("<key>ProductVersion</key>")
    if not found:
        return None
    _, found, rest = rest.partition("<string>")
    if not found:
        return None
    version, found, _ = rest.partition("</string>")
    if not found:
        return None
    return version.strip()

def _detect_macos_version(rctx):
    plist = rctx.path(_SYSTEM_VERSION_PLIST)

    # Rerun the repo rule when the OS is updated.
    rctx.watch(plist)
    if not plist.exists:
        return None
    version = _extract_product_version(rctx.read(plist, watch = "yes"))
    if not version:
        return None
    return floor_macos_version(version)

def _os_version_constraints_impl(rctx):
    load_statements = []
    constraint_exprs = []
    if Label("@platforms//os:osx") in [Label(constraint) for constraint in HOST_CONSTRAINTS]:
        macos_version = _detect_macos_version(rctx)
        if macos_version:
            load_statements.append(
                'load("{label}", "macos_version_constraints")'.format(
                    label = Label("//os/macos/version:macos.bzl"),
                ),
            )
            constraint_exprs.append(
                'macos_version_constraints("{version}")'.format(version = macos_version),
            )

    rctx.file("BUILD.bazel", 'exports_files(["constraints.bzl"])\n')
    rctx.file("constraints.bzl", "\n".join(load_statements) + (
        "\n\n" if load_statements else ""
    ) + "OS_VERSION_CONSTRAINTS = {}\n".format(
        " + ".join(constraint_exprs) if constraint_exprs else "[]",
    ))

    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(
            reproducible = True,
        )
    else:
        return None

os_version_constraints = repository_rule(
    implementation = _os_version_constraints_impl,
)

parsing_for_tests = struct(
    extract_product_version = _extract_product_version,
)
