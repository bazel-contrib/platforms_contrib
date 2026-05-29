load("@with_cfg.bzl", "with_cfg")

modern_genrule, _modern_genrule = (
    with_cfg(native.genrule)
        .set("platforms", [Label("//libc:modern_linux")])
        .build()
)
