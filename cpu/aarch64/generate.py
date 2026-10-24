#!/usr/bin/env python3
"""Generates aarch64_features.bzl and prebuilt/aarch64_cpu_models.inc from the llvm module's sources.

Usage, from the repository root:

    bazel run //cpu/aarch64:generate

The inputs are AArch64Features.td and Host.cpp of the LLVM version pinned by the llvm module in
MODULE.bazel; to move to a newer LLVM, update that pin. Only the Python standard library is used.

What is extracted:

  * Every `ExtensionWithMArch<"TargetFeatureName", ...>` record. The public token is the `-march`
    spelling: `TargetFeatureName`, unless a `let ... UserVisibleName = "X" in` line directly
    precedes the `def` of that record, in which case it is `X`. The meta-alias `crypto` is dropped
    because it is a version-dependent bundle.
  * The MIDR (implementer, part) -> -mcpu name table in getHostCPUNameForARM.
"""

import os
import re
import sys

from python.runfiles import runfiles

TD_PATH = "llvm/lib/Target/AArch64/AArch64Features.td"
HOST_PATH = "llvm/lib/TargetParser/Host.cpp"

# Meta-aliases that are not a single feature.
DROPPED_FEATURES = frozenset(["crypto"])

REGENERATE_COMMAND = "bazel run //cpu/aarch64:generate"

# MIDR implementer blocks and the per-part -mcpu names inside them, in getHostCPUNameForARM.
_IMPLEMENTER = re.compile(r'Implementer == "(0x[0-9a-fA-F]+)"')
_CASE = re.compile(r'\.Case\("(0x[0-9a-fA-F]+)",\s*"([^"]+)"\)')

# A `let` line applies to the `def` that immediately follows it. Only whitespace may separate them.
_RECORD = re.compile(
    r"""
    (?:^let[ \t]+(?P<let>[^\n]*?)[ \t]+in[ \t]*\n\s*)?   # optional `let ... in`
    ^def[ \t]+\w+[ \t]*:[ \t]*ExtensionWithMArch
    <[ \t]*(?P<args>.*?)>                                 # template arguments, up to the closing >
    """,
    re.MULTILINE | re.VERBOSE | re.DOTALL,
)
_ASSIGNMENT = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
_LLVM_VERSION = re.compile(r'llvm_version\s*=\s*"([^"]+)"')

# Longest one-line gloss kept next to a feature; longer LLVM descriptions are truncated at a word.
_DESCRIPTION_CAP = 66


def normalize_desc(text):
    """Reduces an LLVM feature description to a one-line gloss: drop a leading "Enable", then cap."""
    text = " ".join(text.split())
    text = re.sub(r"^Enables?\s+", "", text)
    if len(text) > _DESCRIPTION_CAP:
        text = text[:_DESCRIPTION_CAP].rsplit(" ", 1)[0] + "..."
    return text


def strip_comments(text):
    return re.sub(r"//[^\n]*", "", text)


def parse(text):
    """Returns (sorted feature tokens, {token: gloss}, {token: -mattr name})."""
    features = set()
    descriptions = {}
    mattr_overrides = {}
    for match in _RECORD.finditer(strip_comments(text)):
        overrides = dict(_ASSIGNMENT.findall(match.group("let") or ""))
        args = match.group("args")
        name = re.match(r'"([^"]+)"', args)
        if not name:
            raise SystemExit("Cannot parse ExtensionWithMArch arguments: " + args)
        target_feature_name = name.group(1)
        if target_feature_name in DROPPED_FEATURES:
            continue
        token = overrides.get("UserVisibleName", target_feature_name)
        if token in features:
            raise SystemExit("Duplicate -march token: " + token)
        features.add(token)
        # The -march token (UserVisibleName) differs from the -mattr/-target-feature name
        # (TargetFeatureName) for a few extensions, e.g. simd -> neon. Record those.
        if token != target_feature_name:
            mattr_overrides[token] = target_feature_name
        # Positional args are "TargetFeatureName", "Spelling", "ArchitectureFeatureName", "Desc".
        quoted = re.findall(r'"([^"]*)"', args)
        desc = normalize_desc(quoted[3]) if len(quoted) >= 4 else ""
        if desc:
            descriptions[token] = desc
    if not features:
        raise SystemExit("Parsed no features; has the .td format changed?")
    return sorted(features), descriptions, mattr_overrides


def parse_cpu_models(host_text):
    """Returns [(implementer, part, -mcpu name)] from getHostCPUNameForARM's per-vendor tables.

    Each `.Case("0xPPP", "name")` is attributed to the implementer(s) of the enclosing
    `if (Implementer == "0xNN")` block. Variant-disambiguated parts (Samsung Exynos, which use a
    C `switch` rather than `.Case`) and the big.LITTLE/SoC-name special cases are not `.Case`s, so
    they are skipped; an unlisted (implementer, part) later yields an empty model.
    """
    start = host_text.index("getHostCPUNameForARMFromComponents")
    end = host_text.index("getHostCPUNameForARM(StringRef", start)
    models = []
    seen = set()
    implementers = []
    for line in host_text[start:end].splitlines():
        found = _IMPLEMENTER.findall(line)
        if found:
            implementers = [int(value, 16) for value in found]
        for part, name in _CASE.findall(line):
            for implementer in implementers:
                key = (implementer, int(part, 16))
                if key not in seen:
                    seen.add(key)
                    models.append((key[0], key[1], name))
    if not models:
        raise SystemExit("Parsed no CPU models; has Host.cpp changed?")
    return models


def render_cpu_models(models, version):
    lines = [
        "// GENERATED FILE, DO NOT EDIT BY HAND.",
        "//",
        "// Source: llvm-project {} (the llvm module in MODULE.bazel), {}".format(version, HOST_PATH),
        "// getHostCPUNameForARMFromComponents(). Regenerate: {}".format(REGENERATE_COMMAND),
        "//",
        "// (MIDR implementer, part) -> LLVM -mcpu name. Parts are matched numerically (the source",
        "// spells some with and some without leading zeros). Variant-disambiguated parts (Samsung",
        "// Exynos) and big.LITTLE/SoC-name special cases are omitted; an unlisted pair gives \"\".",
        "static const struct {",
        "  unsigned implementer;",
        "  unsigned part;",
        "  const char *mcpu;",
        "} kAarch64CpuModels[] = {",
    ]
    lines += ['    {{0x{:02x}, 0x{:03x}, "{}"}},'.format(impl, part, name) for impl, part, name in models]
    lines.append("};")
    return "\n".join(lines) + "\n"


def render_list(name, values, descriptions=None):
    lines = ["{} = [".format(name)]
    for value in values:
        entry = '    "{}",'.format(value)
        desc = (descriptions or {}).get(value)
        if desc:
            entry += "  # {}".format(desc)
        lines.append(entry)
    lines.append("]")
    return "\n".join(lines)


def render_mattr_map(overrides):
    lines = ["AARCH64_MARCH_TO_MATTR = {"]
    lines += ['    "{}": "{}",'.format(token, overrides[token]) for token in sorted(overrides)]
    lines.append("}")
    return "\n".join(lines)


def render(features, version, descriptions, mattr_overrides):
    return "\n".join([
        "# GENERATED FILE, DO NOT EDIT BY HAND.",
        "#",
        "# Source: llvm-project {} (the llvm module in MODULE.bazel), {}".format(version, TD_PATH),
        "# Regenerate: {}".format(REGENERATE_COMMAND),
        "",
        'visibility(["//cpu/aarch64/...", "//private", "//tests"])',
        "",
        "# Public -march tokens of the architecture extensions (`UserVisibleName` where LLVM",
        "# overrides the target feature name), excluding the meta-alias `crypto`. The comment on each",
        '# is LLVM\'s description for the feature, with a leading "Enable" dropped.',
        render_list("AARCH64_FEATURES", features, descriptions),
        "",
        "# The LLVM target-feature (-mattr) name for each -march token where the two differ (the token",
        "# is LLVM's UserVisibleName; this is the TargetFeatureName). A consumer turning the feature",
        "# constraints into an -mattr / --target-feature string maps through this; a token not listed",
        "# here is already its own -mattr name.",
        render_mattr_map(mattr_overrides),
        "",
    ])


def read(rlocation):
    with open(runfiles.Create().Rlocation(rlocation), encoding="utf-8") as f:
        return f.read()


def main(argv):
    if len(argv) != 3:
        raise SystemExit("usage: {}".format(REGENERATE_COMMAND))
    workspace = os.environ.get("BUILD_WORKSPACE_DIRECTORY")
    if not workspace:
        raise SystemExit("Run this with `{}` so it can write into the repository.".format(REGENERATE_COMMAND))
    with open(os.path.join(workspace, "MODULE.bazel"), encoding="utf-8") as f:
        version = _LLVM_VERSION.search(f.read()).group(1)
    features, descriptions, mattr_overrides = parse(read(argv[1]))
    models = parse_cpu_models(read(argv[2]))
    missing = [feature for feature in features if feature not in descriptions]
    if missing:
        print("warning: no description for: " + ", ".join(missing), file=sys.stderr)
    features_output = os.path.join(workspace, "cpu", "aarch64", "aarch64_features.bzl")
    models_output = os.path.join(workspace, "prebuilt", "aarch64_cpu_models.inc")
    with open(features_output, "w", encoding="utf-8") as f:
        f.write(render(features, version, descriptions, mattr_overrides))
    with open(models_output, "w", encoding="utf-8") as f:
        f.write(render_cpu_models(models, version))
    print("Wrote {}: {} features from llvm-project {}".format(features_output, len(features), version))
    print("Wrote {}: {} CPU models".format(models_output, len(models)))


if __name__ == "__main__":
    main(sys.argv)
