load("@bazel_features//:features.bzl", "bazel_features")

visibility(["//..."])

def compat_platform(name, flags = [], **kwargs):
    if flags and bazel_features.rules.platform_has_flags:
        kwargs = kwargs | {"flags": flags}
    native.platform(
        name = name,
        **kwargs
    )
