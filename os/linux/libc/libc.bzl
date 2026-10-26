"""The libc flavor that toolchains should target on Linux platforms."""

PreferredLibcInfo = provider(
    doc = """The result of resolving //os/linux/libc:preference against the target platform.

Provided by //os/linux/libc:preferred.""",
    fields = {
        "diagnostic": "Why no option is viable if `status` is \"unresolved\", otherwise empty. " +
                      "The wording isn't stable.",
        "flavor": "The preferred flavor, currently \"glibc\" or \"musl\", if `status` is " +
                  "\"resolved\", otherwise None. More flavors may be added in the future.",
        "requires_fully_static": "Whether binaries have to be linked fully statically if " +
                                 "`status` is \"resolved\", otherwise None.",
        "status": "\"resolved\" for Linux platforms with a viable option, \"unresolved\" for " +
                  "Linux platforms without one and \"not_applicable\" for other platforms.",
    },
)

def check_preferred_libc(preferred_libc):
    """Fails with an actionable error if no libc option is viable on a Linux target platform.

    Args:
      preferred_libc: The PreferredLibcInfo of //os/linux/libc:preferred.

    Returns:
      The given PreferredLibcInfo.
    """
    if preferred_libc.status == "unresolved":
        fail(preferred_libc.diagnostic)
    return preferred_libc
