load("@with_cfg.bzl", "with_cfg")

host_genrule, _host_genrule = (
    with_cfg(native.genrule)
        .set("platforms", [Label("@platforms_contrib//host")])
        .build()
)
