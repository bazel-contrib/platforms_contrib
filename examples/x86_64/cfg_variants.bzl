load("@with_cfg.bzl", "with_cfg")

v4_genrule, _v4_genrule = (
    with_cfg(native.genrule)
        .set("platforms", [Label("//x86_64:x86_64_v4")])
        .build()
)
