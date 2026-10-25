# platforms_contrib

platforms_contrib provides standardized constraints and flags for expressive Bazel platform definitions, beyond the standard OS and CPU constraints provided by [bazelbuild/platforms](https://github.com/bazelbuild/platforms).
It currently covers:

* [libc flavor, version and preference](#libc-flavor-and-version-linux-only) (currently Linux only)
* [CPU features and model](#cpu-features-and-model-x86-64-only) (currently x86-64 only)

We plan to work on support for non-Linux OSes and ARM CPUs next.
Suggestions and PRs are welcome!

Use these constraints instead of defining your own when authoring toolchains, rules or BUILD files.
platforms_contrib also provides [host platforms](#auto-detected-host-platforms) that are auto-detected with these constraints.

**Note:** platforms_contrib is currently in alpha and may change in backwards-incompatible ways at any time.
We plan to reach version 1.0.0 soon and will heavily emphasize backwards compatibility at that point.

## Setup

Add the following to your `MODULE.bazel` file, using the latest version from the [releases page](https://github.com/bazel-contrib/platforms_contrib/releases):

```starlark
bazel_dep(name = "platforms_contrib", version = "<version>")
```

platforms_contrib supports Bazel 7.1.0 and later.
Some features require newer versions of Bazel as noted below.

## Auto-detected host platforms

platforms_contrib provides two auto-detected host platforms:

* `@platforms_contrib//host:generic` provides the OS and CPU constraints of `@platforms//host`, Bazel's default host platform, together with constraints for the libc flavors and versions available on the host machine (rounded to certain buckets for better cache sharing across machines).
  This can be used as a drop-in replacement for the default platform and will always model a wide range of machines compatible with the host.
* `@platforms_contrib//host:native` doesn't round the libc versions to buckets and additionally sets constraints for the features of the host machine's CPU and a flag for its model (x86-64 hosts only).
  This can be used as a hermetic replacement for `-march=native` type compiler flags.

The exact constraints provided by these platforms are not covered by any backwards compatibility guarantee and should not be relied upon.

Use either of these platforms by adding this to your `.bazelrc` (possibly replacing `generic` with `native`):

```text
common --host_platform=@platforms_contrib//host:generic
# Workaround for https://github.com/bazelbuild/bazel/issues/25145
# Planned to be fixed in Bazel 9.4.0 and 10.0.0.
info --host_platform=@platforms//host
```

Unless `--platforms` is set, the host platform is also the target platform.
It is also implicitly registered as an execution platform.

## libc flavor and version (Linux only)

For each supported version of glibc (2.15 and later) and musl (1.0 and later), there is a `constraint_value` expressing that *at least* this version is available:

```text
@platforms_contrib//os/linux/libc/glibc:at_least_2.<minor>_available
@platforms_contrib//os/linux/libc/musl:at_least_1.<minor>_available
```

The two flavors are modeled independently: a platform can provide glibc, musl, both or neither.

### Toolchain definitions

A toolchain can be constrained by the minimum libc versions, both via `exec_compatible_with` for its binaries that run during the build (e.g. a compiler) and via `target_compatible_with` for the outputs it produces that run on the target platform.

#### Example

A C++ toolchain that produces binaries dynamically linked against musl and whose compiler runs on hosts with glibc 2.28 and later:

```starlark
toolchain(
    name = "musl_cc_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        # The compiler binaries require glibc 2.28 and later.
        "@platforms_contrib//os/linux/libc/glibc:at_least_2.28_available",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        # The produced binaries require musl of any version to be installed.
        "@platforms_contrib//os/linux/libc/musl:at_least_1.0_available",
    ],
    toolchain = ":musl_cc_toolchain_impl",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
```

### Usage in BUILD files and rules

The constraints above track the availability of a particular libc version, but intentionally do not track which one is actually compiled and linked against.
This is inherently a property of the C++ toolchain, so use the `config_setting`s in `@rules_cc//cc/libc` in `select()` conditions.

#### Example

A library that needs to base decisions on whether it uses musl:

```starlark
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "base",
    srcs = ["base.c"],
    local_defines = select({
        "@rules_cc//cc/libc:musl": ["USES_MUSL"],
        "//conditions:default": [],
    }),
)
```

To use the version of glibc or musl available on the target platform in a BUILD file, add `@platforms_contrib//os/linux/libc/glibc:target_version` or `@platforms_contrib//os/linux/libc/musl:target_version` to the `toolchains` attribute of a target and use the `$(GLIBC_VERSION)` or `$(MUSL_VERSION)` Make variable, respectively.
If the respective libc flavor is not available on the target platform, the version is empty.

A rule can read the versions from the `$(GLIBC_VERSION)` and `$(MUSL_VERSION)` Make variables or directly from the `platform_common.TemplateVariableInfo` provider of these targets.

### Custom platform definitions

Use the `glibc_version_constraints` and `musl_version_constraints` functions, which return the `constraint_value`s for the given version and all lower versions.
This enables the range semantics of `at_least_<major>.<minor>_available`.

#### Example

Ubuntu 22.04 on x86-64 with the `musl` package installed:

```starlark
load("@platforms_contrib//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("@platforms_contrib//os/linux/libc/musl:musl.bzl", "musl_version_constraints")

platform(
    name = "ubuntu_22_04_x86_64",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ] + glibc_version_constraints("2.35") + musl_version_constraints("1.2"),
)
```

Always use these functions instead of listing individual `constraint_value`s as new values may be added.
Bazel 9.2.0 and later enforce completeness.

### Preferred flavor

Platforms that provide both glibc and musl, or neither, leave the choice of the libc to toolchains.
All toolchains that contribute to the same binary have to make the same choice, e.g. a Rust staticlib linked into a C++ binary.
To that end, the list flag `@platforms_contrib//os/linux/libc:preference` ranks the following options and defaults to `glibc,musl`:

* `glibc` and `musl`: target the flavor, which is viable if the target platform declares it as available.
  Binaries don't have to be linked fully statically.
* `static-musl` and `static-glibc`: target the flavor and link all binaries fully statically, which is viable on every Linux platform.
  Depending on the features they use and the configuration of the machine, fully static glibc binaries may still load shared objects of the exact glibc version used for linking at runtime, e.g. for NSS sources other than `files` and `dns` (as of glibc 2.34), iconv and `dlopen`.
  For self-contained binaries, avoid these features or ship the matching shared objects.

The preferred option is the first viable one.
A platform without libc constraints doesn't declare any libc as available, so only the fully static options are viable on it.
This also describes container images such as `scratch`, but it applies to Bazel's default host platform `@platforms//host` as well.
To target the libc of the host, use `@platforms_contrib//host:generic` as the host platform.

Typical rankings are:

| Intent | Ranking |
|---|---|
| Prefer the platform's glibc, otherwise its musl | `glibc,musl` |
| Prefer the platform's musl, otherwise its glibc | `musl,glibc` |
| Build portable, fully static binaries for all Linux platforms | `static-musl` |
| Use the platform's glibc, otherwise build fully static binaries (e.g. for `scratch` or Alpine images) | `glibc,static-musl` |
| The same for code that requires glibc | `glibc,static-glibc` |

On Bazel 9 and later, exec transitions reset the ranking to the default, so that the ranking for the target platform doesn't affect tools.
On Bazel 7 and 8, the ranking also applies to exec configurations by default.
Don't set the ranking via the `flags` of a platform: it would override the ranking chosen by the user and carry over to other platforms after transitions.

#### Following the preference

Toolchains and rules that choose a libc should follow the preference instead of making their own choice, using the following targets in `@platforms_contrib//os/linux/libc`:

* `:glibc_preferred` and `:musl_preferred` match the preferred flavor.
* `:requires_fully_static` matches if binaries have to be linked fully statically.
  Toolchains should then link all binaries fully statically, e.g. by enabling the `fully_static_link` feature of a C++ toolchain, and fail for binaries that can't be, e.g. because they depend on shared libraries.
  Otherwise, individual binaries can still be linked fully statically, e.g. via `features = ["fully_static_link"]`.
* `:allows_dynamic` matches if the preference resolved and binaries don't have to be linked fully statically.
* `:unresolved` matches Linux platforms without a viable option.
* `:preferred` provides `PreferredLibcInfo` (from `@platforms_contrib//os/linux/libc:libc.bzl`) and the Make variables `PREFERRED_LIBC`, `PREFERRED_LIBC_REQUIRES_FULLY_STATIC` and `PREFERRED_LIBC_STATUS`.

Resolving a valid ranking never fails: on a Linux platform without a viable option, none of the settings except `:unresolved` match and the status is `unresolved`.
This allows toolchains to use the settings in their `target_settings`, which Bazel evaluates for every registered toolchain in every configuration, even when resolving an unrelated toolchain type.
Since the preference may be unresolved, don't treat `//conditions:default` as one of the flavors.
To fail with an actionable error instead of "No matching toolchains found", a toolchain type can have an additional toolchain that is selected on `:unresolved` and calls `check_preferred_libc` from `libc.bzl`.
To diagnose a platform directly, build `@platforms_contrib//os/linux/libc:validate_preference` for it.

The preferred option doesn't depend on which toolchains are registered.
For example, if the target platform only declares glibc 2.17 and the ranking is `glibc,static-musl`, glibc is preferred even if the C++ toolchain requires glibc 2.28.
Toolchains should express such requirements as constraints and must not fall back to a different flavor.
Code that depends on the libc it is actually compiled against should still use the `config_setting`s in `@rules_cc//cc/libc`.

#### Example

Toolchains for glibc and fully static musl, plus a toolchain that fails with an actionable error:

```starlark
toolchain(
    name = "linux_x86_64_glibc",
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
        "@platforms_contrib//os/linux/libc/glibc:at_least_2.28_available",
    ],
    target_settings = [
        "@platforms_contrib//os/linux/libc:glibc_preferred",
        "@platforms_contrib//os/linux/libc:allows_dynamic",
    ],
    toolchain = ":linux_x86_64_glibc_impl",
    toolchain_type = ":toolchain_type",
)

toolchain(
    name = "linux_x86_64_static_musl",
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_settings = ["@platforms_contrib//os/linux/libc:musl_preferred"],
    toolchain = ":linux_x86_64_static_musl_impl",
    toolchain_type = ":toolchain_type",
)

toolchain(
    name = "unresolved_libc",
    target_compatible_with = ["@platforms//os:linux"],
    target_settings = ["@platforms_contrib//os/linux/libc:unresolved"],
    # A rule that calls check_preferred_libc on the PreferredLibcInfo of
    # @platforms_contrib//os/linux/libc:preferred. Tag it "manual" as it fails when built directly
    # for such a platform.
    toolchain = ":unresolved_libc_impl",
    toolchain_type = ":toolchain_type",
)
```

A Linux-only target that depends on the flavor:

```starlark
my_lang_library(
    name = "lib",
    target_compatible_with = ["@platforms//os:linux"],
    target_triple = select(
        {
            "@platforms_contrib//os/linux/libc:glibc_preferred": "x86_64-unknown-linux-gnu",
            "@platforms_contrib//os/linux/libc:musl_preferred": "x86_64-unknown-linux-musl",
        },
        no_match_error = "No libc preference resolved, see @platforms_contrib//os/linux/libc:validate_preference",
    ),
)
```

## CPU features and model (x86-64 only)

**Features:** For each non-obsolete x86-64 CPU feature recognized by LLVM (e.g. `avx2`, `avx512f` or `sha`) and some additional CPUID capabilities (e.g. `ermsb` or `fsrm`), the package `@platforms_contrib//cpu/x86_64/feature` defines:

* the `constraint_value`s `<feature>_available` and `<feature>_unavailable` for platforms and toolchains
* the `config_setting`s `<feature>` and `no_<feature>` for `select()`

Features of the x86-64 baseline (`fxsr`, `mmx`, `sse`, `sse2` and `x87`) default to available, all other features to unavailable.
See [`x86_64_private.bzl`](cpu/x86_64/x86_64_private.bzl) for the full list of features.

**Levels:** The [x86-64 microarchitecture levels](https://gitlab.com/x86-psABIs/x86-64-ABI) `v1` to `v4` are recognized by the set of features they imply.
The `x86_64_level_constraints("vN")` function in `@platforms_contrib//cpu/x86_64:x86_64.bzl` returns the `constraint_value`s for all features of level N and below, and the `config_setting` `@platforms_contrib//cpu/x86_64:at_least_vN` matches platforms that provide them.

**Model:** The string flag `@platforms_contrib//cpu/x86_64:model` holds the LLVM name (as accepted by clang's `-march` and `-mtune`, e.g. `znver4`) of the specific CPU a platform corresponds to, or is empty.
The model is intentionally provided as a flag rather than a constraint and should never be used to derive information about the availability of features.

### Toolchain definitions

A toolchain can be constrained by the features it requires on the execution or target platform, either individually or by microarchitecture level.

#### Example

A toolchain with a prebuilt runtime library compiled with `-march=x86-64-v3 -msha`:

```starlark
load("@platforms_contrib//cpu/x86_64:x86_64.bzl", "x86_64_level_constraints")

toolchain(
    name = "runtime_x86_64_v3_sha",
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "@platforms_contrib//cpu/x86_64/feature:sha_available",
    ] + x86_64_level_constraints("v3"),
    toolchain = ":runtime_x86_64_v3_sha_impl",
    toolchain_type = "//runtime:toolchain_type",
)
```

### Usage in BUILD files and rules

Use the `config_setting`s for levels and individual features as `select()` conditions.

#### Example

A library that is optimized for the highest level supported by the target platform and uses `avx512fp16` if available:

```starlark
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "matmul",
    srcs = select({
        "@platforms_contrib//cpu/x86_64:at_least_v4": ["matmul_v4.c"],
        "@platforms_contrib//cpu/x86_64:at_least_v3": ["matmul_v3.c"],
        "@platforms_contrib//cpu/x86_64:at_least_v2": ["matmul_v2.c"],
        "//conditions:default": ["matmul_generic.c"],
    }) + select({
        "@platforms_contrib//cpu/x86_64/feature:avx512fp16": ["matmul_avx512fp16.c"],
        "//conditions:default": [],
    }),
)
```

Each level includes all lower levels, so the highest matching level is the most specialized condition and wins.
In contrast, conditions for different features are generally ambiguous on platforms that have both, so use separate `select()`s for them as above.

To use the model in a BUILD file, add `@platforms_contrib//cpu/x86_64:model` to the `toolchains` attribute of a target and use the `$(X86_64_MODEL)` Make variable.

A rule can read the model of the target platform from the `$(X86_64_MODEL)` Make variable or directly from the `platform_common.TemplateVariableInfo` provider of `@platforms_contrib//cpu/x86_64:model`, e.g. to pass it to `-mtune`.

### Custom platform definitions

List the features of the platform's CPUs, individually or by level, and set the model via `flags` (Bazel 8.0.0 and later) if the platform corresponds to a specific CPU.

#### Example

A Linux machine with AMD Zen 4 CPUs:

```starlark
load("@platforms_contrib//cpu/x86_64:x86_64.bzl", "x86_64_level_constraints")

platform(
    name = "linux_znver4",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "@platforms_contrib//cpu/x86_64/feature:aes_available",
        "@platforms_contrib//cpu/x86_64/feature:sha_available",
        "@platforms_contrib//cpu/x86_64/feature:vaes_available",
    ] + x86_64_level_constraints("v4"),
    flags = ["--@platforms_contrib//cpu/x86_64:model=znver4"],
)
```

Features that are not listed count as unavailable (except for the baseline), so a platform may conservatively omit features.

A platform's flags persist after transitions to platforms that don't set them.
Platforms that don't correspond to a specific CPU should thus reset the model with `flags = ["--@platforms_contrib//cpu/x86_64:model="]`, as `@platforms_contrib//host:generic` does.
This is planned to be fixed in Bazel 9.4.0 and later.
