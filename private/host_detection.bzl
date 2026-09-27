load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load(":cpu_feature_constraints.bzl", "cpu_feature_constraints")
load(":libc_constraints.bzl", "libc_constraints")
load(":prebuilts.bzl", "PREBUILT_DETECTORS", "prebuilt_detector_file_name", "prebuilt_detector_repo_name")

def _host_detection_impl(mctx):
    prohibited_users = [module.name for module in mctx.modules if module.name != "platforms_contrib"]
    if prohibited_users:
        fail(
            "platforms_contrib's host detection module extension must not be used by other modules: " +
            ", ".join(prohibited_users),
        )

    libc_constraints(
        name = "libc_constraints",
    )

    cpu_feature_constraints(
        name = "cpu_feature_constraints",
    )

    # One http_file repo per prebuilt detector binary. Repos are fetched lazily, so only the repo
    # matching the host platform (if any) is ever downloaded, by cpu_feature_constraints.
    for (os, cpu), prebuilt in PREBUILT_DETECTORS.items():
        http_file(
            name = prebuilt_detector_repo_name(os, cpu),
            downloaded_file_path = prebuilt_detector_file_name(prebuilt),
            executable = True,
            integrity = prebuilt.integrity,
            url = prebuilt.url,
        )

    return mctx.extension_metadata(
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

host_detection = module_extension(
    implementation = _host_detection_impl,
)
