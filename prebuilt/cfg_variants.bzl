load("@with_cfg.bzl", "with_cfg")

linux_x86_64_filegroup, _linux_x86_64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:linux_x86_64_musl")])
        .build()
)

macos_x86_64_filegroup, _macos_x86_64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:macos_x86_64")])
        .build()
)

windows_x86_64_filegroup, _windows_x86_64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:windows_x86_64")])
        .build()
)

# aarch64 variants. The llvm module's declare_platforms() names platforms "{os}_{cpu}" and
# "{os}_{cpu}_{libc}", so these mirror the x86-64 labels above. Windows on Arm is omitted until the
# llvm module's windows_aarch64 cross-compile target is confirmed.
linux_aarch64_filegroup, _linux_aarch64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:linux_aarch64_musl")])
        .build()
)

macos_aarch64_filegroup, _macos_aarch64_filegroup = (
    with_cfg(native.filegroup)
        .set("platforms", [Label("@llvm//platforms:macos_aarch64")])
        .build()
)
