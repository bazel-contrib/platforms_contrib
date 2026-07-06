load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//os/linux/libc/glibc:glibc_private.bzl", "GLIBC_VERSIONS")
load("//os/linux/libc/musl:musl_private.bzl", "MUSL_VERSIONS")

visibility("private")

# These Label calls rely on platforms_contrib using the "platforms" repo name for the "platforms"
# module as HOST_CONSTRAINTS consists of raw label strings.
_HOST_CONSTRAINTS = [Label(constraint) for constraint in HOST_CONSTRAINTS]

# Maps a CPU constraint value potentially emitted by @platforms//host to the corresponding standard
# PT_INTERP path of glibc's dynamic loader.
_GLIBC_LD_PATHS = {
    Label("@platforms//cpu:x86_64"): ["/lib64/ld-linux-x86-64.so.2"],
    Label("@platforms//cpu:x86_32"): ["/lib/ld-linux.so.2"],
    Label("@platforms//cpu:aarch64"): ["/lib/ld-linux-aarch64.so.1"],
    # ld-linux-armhf.so.3 is the hard-float loader, ld-linux.so.3 the soft-float one.
    Label("@platforms//cpu:arm"): ["/lib/ld-linux-armhf.so.3", "/lib/ld-linux.so.3"],
    Label("@platforms//cpu:ppc64le"): ["/lib64/ld64.so.2"],
    # @platforms//host maps both 32-bit powerpc and big-endian ppc64 (ELFv1) hosts to the "ppc"
    # constraint.
    Label("@platforms//cpu:ppc"): ["/lib64/ld64.so.1", "/lib/ld.so.1"],
    Label("@platforms//cpu:s390x"): ["/lib/ld64.so.1"],
    # lp64d is the double-float RISC-V ABI that's the default for most glibc distros.
    Label("@platforms//cpu:riscv64"): ["/lib/ld-linux-riscv64-lp64d.so.1"],
    Label("@platforms//cpu:mips64"): ["/lib64/ld.so.1", "/lib64/ld-linux-mipsn8.so.1"],
}

# musl's dynamic loader is always installed as /lib/ld-musl-$ARCH.so.1, where $ARCH is the musl
# architecture name, which encodes endianness and float ABI where relevant.
_MUSL_LD_PATHS = {
    Label("@platforms//cpu:x86_64"): ["/lib/ld-musl-x86_64.so.1"],
    Label("@platforms//cpu:x86_32"): ["/lib/ld-musl-i386.so.1"],
    Label("@platforms//cpu:aarch64"): ["/lib/ld-musl-aarch64.so.1"],
    Label("@platforms//cpu:arm"): ["/lib/ld-musl-armhf.so.1", "/lib/ld-musl-arm.so.1"],
    Label("@platforms//cpu:ppc64le"): ["/lib/ld-musl-powerpc64le.so.1"],
    Label("@platforms//cpu:ppc"): ["/lib/ld-musl-powerpc64.so.1", "/lib/ld-musl-powerpc.so.1"],
    Label("@platforms//cpu:s390x"): ["/lib/ld-musl-s390x.so.1"],
    Label("@platforms//cpu:riscv64"): ["/lib/ld-musl-riscv64.so.1"],
    Label("@platforms//cpu:mips64"): ["/lib/ld-musl-mips64el.so.1", "/lib/ld-musl-mips64.so.1"],
}

def _version_key(version):
    major, _, minor = version.partition(".")
    return (int(major), int(minor))

def _extract_version_key(text, marker):
    start = text.find(marker)
    if start == -1:
        return None
    start += len(marker)
    end = start

    # Put an arbitrary but reasonable limit on the length of a version string to avoid creating
    # huge integers from garbage data below.
    for i in range(start, min(start + 16, len(text))):
        if text[i] not in "0123456789.":
            break
        end = i + 1
    parts = text[start:end].split(".")
    if len(parts) < 2 or not parts[0].isdigit() or not parts[1].isdigit():
        return None
    return (int(parts[0]), int(parts[1]))

def _floor_to_supported(version_key, sorted_supported_versions):
    for supported in reversed(sorted_supported_versions):
        if _version_key(supported) <= version_key:
            return supported
    return None

def _find_ld(rctx, ld_paths):
    for constraint in _HOST_CONSTRAINTS:
        for path in ld_paths.get(constraint, []):
            ld = rctx.path(path)

            # This watch is crucial for incremental correctness: If one of the files changes
            # contents, appears, or disappears, the repo rule must rerun to pick up the new version.
            rctx.watch(ld)
            if ld.exists:
                return ld
    return None

# Bazel's release binaries reference versioned glibc symbols up to GLIBC_2.17 as of Bazel 6, which
# still supported CentOS 7 (Bazel 7 raised the requirement to glibc 2.28). Any host running Bazel
# thus has at least glibc 2.17, which makes it a safe lower bound when the loader predates the
# version banner.
_FALLBACK_GLIBC_VERSION_KEY = (2, 17)

def _detect_glibc_version(rctx):
    ld = _find_ld(rctx, _GLIBC_LD_PATHS)
    if not ld:
        return None

    # ld.so embeds its --version banner, which contains "release version 2.XY." as a compile-time
    # string literal, since glibc 2.33 (commit 542923d949e8, "elf: Implement ld.so --version") as
    # well as in distro builds that backported the ld.so CLI (e.g. RHEL 8's glibc 2.28). Loaders
    # without the banner (e.g. Debian 11's pristine glibc 2.31) are detected as the fallback
    # version.
    version_key = _extract_version_key(rctx.read(ld, watch = "yes"), "release version ")
    if not version_key:
        version_key = _FALLBACK_GLIBC_VERSION_KEY
    return _floor_to_supported(version_key, GLIBC_VERSIONS)

def _detect_musl_version(rctx):
    ld = _find_ld(rctx, _MUSL_LD_PATHS)
    if not ld:
        return None

    # Unlike glibc's ld.so, musl's loader only embeds a "Version %s" format string with the version
    # filled in at runtime, so it can't be found by scanning the binary. When run without arguments,
    # the loader prints a usage message including a "Version 1.X.Y" line to stderr. This invalidates
    # correctly since musl is a single standalone dynamic library that doubles as the libc, so there
    # is no separate file to watch.
    version_key = _extract_version_key(rctx.execute([ld]).stderr, "Version ")
    if not version_key:
        return None
    return _floor_to_supported(version_key, MUSL_VERSIONS)

def _libc_constraints_impl(rctx):
    load_statements = []
    constraint_exprs = []
    if Label("@platforms//os:linux") in _HOST_CONSTRAINTS:
        glibc_version = _detect_glibc_version(rctx)
        if glibc_version:
            load_statements.append(
                'load("{label}", "glibc_version_constraints")'.format(
                    label = Label("//os/linux/libc/glibc:glibc.bzl"),
                ),
            )
            constraint_exprs.append(
                'glibc_version_constraints("{version}")'.format(version = glibc_version),
            )

        musl_version = _detect_musl_version(rctx)
        if musl_version:
            load_statements.append(
                'load("{label}", "musl_version_constraints")'.format(
                    label = Label("//os/linux/libc/musl:musl.bzl"),
                ),
            )
            constraint_exprs.append(
                'musl_version_constraints("{version}")'.format(version = musl_version),
            )

    rctx.file("BUILD.bazel", 'exports_files(["constraints.bzl"])\n')
    rctx.file("constraints.bzl", "\n".join([statement for statement in load_statements]) + (
        "\n\n" if load_statements else ""
    ) + "LIBC_CONSTRAINTS = {}\n".format(
        " + ".join(constraint_exprs) if constraint_exprs else "[]",
    ))

    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(
            reproducible = True,
        )
    else:
        return None

libc_constraints = repository_rule(
    implementation = _libc_constraints_impl,
)

parsing_for_tests = struct(
    extract_version_key = _extract_version_key,
    floor_to_supported = _floor_to_supported,
)
