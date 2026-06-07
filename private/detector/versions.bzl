"""Pinned prebuilt detector binaries.

VERSION is a GitHub release tag of the form ``detector-<short-sha>`` produced
by the ``prebuilt-detector`` workflow. The release attaches one asset per
supported Linux host (cpu) and the workflow updates the SHA-256 values in
this file via PR. The host detection repository rule downloads the matching
asset or compiles the detector from source if no pin exists yet.
"""

VERSION = "detector-unreleased"

BINARIES = {
    "linux_x86_64": {
        "asset": "detector-linux-x86_64",
        "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
    },
    "linux_aarch64": {
        "asset": "detector-linux-aarch64",
        "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
    },
}
