visibility(["//cpu/aarch64/...", "//private", "//tests"])

# Baseline features default to available (Armv8-A mandates them for Linux and macOS userspace);
# explicit negatives support freestanding code. All other features default to unavailable.
AARCH64_BASELINE_FEATURES = ["fp", "simd"]
