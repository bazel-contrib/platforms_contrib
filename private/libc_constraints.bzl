load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("//os/linux/libc/glibc:glibc_private.bzl", "GLIBC_VERSIONS")
load("//os/linux/libc/musl:musl_private.bzl", "MUSL_VERSIONS")

visibility("private")

# These Label calls rely on platforms_contrib using the "platforms" repo name for the "platforms"
# module as HOST_CONSTRAINTS consists of raw label strings.
_HOST_CONSTRAINTS = [Label(constraint) for constraint in HOST_CONSTRAINTS]

# Maps a CPU constraint value potentially emitted by @platforms//host to the corresponding standard
# PT_INTERP path of glib'c dynamic loader.
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

    # Put an arbitary but reasonable limit on the length of a version string to avoid creating huge
    # integers from garbage data below.
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

def _extract_listed_path(text, marker):
    start = text.find(marker)
    if start == -1:
        return None
    start += len(marker)
    end = text.find(" (", start)
    if end == -1:
        return None
    path = text[start:end]
    if not path.startswith("/"):
        return None
    return path

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

def _detect_glibc_version(rctx):
    ld = _find_ld(rctx, _GLIBC_LD_PATHS)
    if not ld:
        return None

    # Since glibc 2.33 (or in distro builds that backported the ld.so CLI, such as RHEL 8's), ld.so
    # embeds its --version banner, which contains "release version 2.XY." as a compile-time string
    # literal.
    version_key = _extract_version_key(rctx.read(ld, watch = "yes"), "release version ")
    if not version_key:
        version_key = _glibc_version_key_from_libc(rctx, ld)
    if not version_key:
        return None
    return _clamp_to_supported(version_key, GLIBC_VERSIONS)

def _glibc_version_key_from_libc(rctx, ld):
    # Older loaders don't embed a version, but libc.so.6 has always carried the same banner. Its
    # path varies by distro (multiarch vs. lib64 layouts), so ask the loader to resolve it for a
    # known dynamically linked executable: "ld.so --list <prog>" prints a "libc.so.6 => <path>"
    # line and predates the loader's --version support by decades.
    sh = rctx.which("sh")
    if not sh:
        return None
    libc_path = _extract_listed_path(rctx.execute([ld, "--list", sh]).stdout, "libc.so.6 => ")
    if not libc_path:
        return None
    return _extract_version_key(rctx.read(libc_path, watch = "yes"), "release version ")

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
    extract_listed_path = _extract_listed_path,
    clamp_to_supported = _clamp_to_supported,
)
