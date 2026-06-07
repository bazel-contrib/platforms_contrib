"""Module extensions for platforms_contrib."""

load("//private:host_detect.bzl", "host_detect")

visibility("public")

def _host_detect_impl(_module_ctx):
    host_detect(name = "platforms_contrib_host_detected")

host_detect_extension = module_extension(
    implementation = _host_detect_impl,
    doc = "Generates @platforms_contrib_host_detected with the host's detected libc constraint values.",
)
