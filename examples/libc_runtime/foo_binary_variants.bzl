load("@with_cfg.bzl", "with_cfg")
load("//rules/foo:defs.bzl", "foo_binary")

modern_foo_binary, _modern_foo_binary = (
    with_cfg(foo_binary)
        .set("platforms", [Label("//libc_runtime:modern_linux")])
        .build()
)

compatible_foo_binary, _compatible_foo_binary = (
    with_cfg(foo_binary)
        .set("platforms", [Label("//libc_runtime:legacy_linux")])
        .build()
)
