load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//os/linux/libc/glibc:glibc_private.bzl", "GLIBC_VERSIONS")
load("//os/linux/libc/musl:musl_private.bzl", "MUSL_VERSIONS")

visibility("private")

# These Label calls require platforms_contrib to use the "platforms" repo name
# for the "platforms" module since HOST_CONSTRAINTS consists of raw label
# strings.
_HOST_CONSTRAINTS = [Label(constraint) for constraint in HOST_CONSTRAINTS]

# The ABI-mandated PT_INTERP paths of glibc's dynamic loader, keyed by the
# CPU constraints @platforms//host can emit. Distros keep these paths working
# (via symlinks if necessary) even with multiarch or merged-usr layouts as
# every dynamically linked executable references them.
_GLIBC_LD_PATHS = {
    Label("@platforms//cpu:x86_64"): ["/lib64/ld-linux-x86-64.so.2"],
    Label("@platforms//cpu:x86_32"): ["/lib/ld-linux.so.2"],
    Label("@platforms//cpu:aarch64"): ["/lib/ld-linux-aarch64.so.1"],
    # ld-linux-armhf.so.3 is the hard-float loader, ld-linux.so.3 the
    # soft-float one.
    Label("@platforms//cpu:arm"): ["/lib/ld-linux-armhf.so.3", "/lib/ld-linux.so.3"],
    Label("@platforms//cpu:ppc64le"): ["/lib64/ld64.so.2"],
    # @platforms//host maps both 32-bit powerpc and big-endian ppc64 (ELFv1)
    # hosts to the "ppc" constraint.
    Label("@platforms//cpu:ppc"): ["/lib64/ld64.so.1", "/lib/ld.so.1"],
    Label("@platforms//cpu:s390x"): ["/lib/ld64.so.1"],
    # lp64d is the double-float RISC-V ABI used by all glibc distros.
    Label("@platforms//cpu:riscv64"): ["/lib/ld-linux-riscv64-lp64d.so.1"],
    # The n64 loader path is the same for both mips64 endiannesses.
    Label("@platforms//cpu:mips64"): ["/lib64/ld.so.1"],
}

# musl's dynamic loader is always installed as /lib/ld-musl-$ARCH.so.1, where
# $ARCH is the musl architecture name, which encodes endianness and float ABI
# where relevant.
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
    for i in range(start, min(start + 16, len(text))):
        if text[i] not in "0123456789.":
            break
        end = i + 1
    parts = text[start:end].split(".")
    if len(parts) < 2 or not parts[0].isdigit() or not parts[1].isdigit():
        return None
    return (int(parts[0]), int(parts[1]))

def _clamp_to_supported(version_key, sorted_supported_versions):
    for supported in reversed(sorted_supported_versions):
        if _version_key(supported) <= version_key:
            return supported
    return sorted_supported_versions[0]

def _find_ld(rctx, ld_paths):
    for constraint in _HOST_CONSTRAINTS:
        for path in ld_paths.get(constraint, []):
            ld = rctx.path(path)
            rctx.watch(ld)
            if ld.exists:
                return ld
    return None

def _detect_glibc_version(rctx):
    ld = _find_ld(rctx, _GLIBC_LD_PATHS)
    if not ld:
        return None

    # glibc's ld.so embeds its --version banner, which always contains
    # "stable release version 2.XY." as a compile-time string literal, even in
    # distro builds that customize the rest of the banner.
    version_key = _extract_version_key(rctx.read(ld, watch = "yes"), "release version ")
    if not version_key:
        return None
    return _clamp_to_supported(version_key, GLIBC_VERSIONS)

def _detect_musl_version(rctx):
    ld = _find_ld(rctx, _MUSL_LD_PATHS)
    if not ld:
        return None

    # Unlike glibc's ld.so, musl's loader only embeds a "Version %s" format
    # string with the version filled in at runtime, so it can't be found by
    # scanning the binary. When run without arguments, the loader prints a
    # usage message including a "Version 1.X.Y" line to stderr.
    version_key = _extract_version_key(rctx.execute([ld]).stderr, "Version ")
    if not version_key:
        return None
    return _clamp_to_supported(version_key, MUSL_VERSIONS)

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
    rctx.file("constraints.bzl", "".join([
        statement + "\n"
        for statement in load_statements
    ]) + ("\n" if load_statements else "") + "LIBC_CONSTRAINTS = {}\n".format(
        " + ".join(constraint_exprs) if constraint_exprs else "[]",
    ))

libc_constraints = repository_rule(
    implementation = _libc_constraints_impl,
)

parsing_for_tests = struct(
    extract_version_key = _extract_version_key,
    clamp_to_supported = _clamp_to_supported,
)
