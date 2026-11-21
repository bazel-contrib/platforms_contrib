load("@with_cfg.bzl", "with_cfg")

macos_26_genrule, _macos_26_genrule = (
    with_cfg(native.genrule)
        .set("platforms", [Label("//macos:macos_26_arm64")])
        .build()
)

# Builds for the same platform, but for users on macOS 12 and later.
macos_26_minimum_12_genrule, _macos_26_minimum_12_genrule = (
    with_cfg(native.genrule)
        .set("platforms", [Label("//macos:macos_26_arm64")])
        .set("macos_minimum_os", "12.0")
        .build()
)
