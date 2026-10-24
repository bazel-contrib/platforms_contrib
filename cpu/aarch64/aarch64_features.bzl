# GENERATED FILE, DO NOT EDIT BY HAND.
#
# Source: llvm-project 23.1.2 (the llvm module in MODULE.bazel), llvm/lib/Target/AArch64/AArch64Features.td
# Regenerate: bazel run //cpu/aarch64:generate

visibility(["//cpu/aarch64/...", "//private", "//tests"])

# Public -march tokens of the architecture extensions (`UserVisibleName` where LLVM
# overrides the target feature name), excluding the meta-alias `crypto`. The comment on each
# is LLVM's description for the feature, with a leading "Enable" dropped.
AARCH64_FEATURES = [
    "aes",  # AES support
    "bf16",  # BFloat16 Extension
    "brbe",  # Branch Record Buffer Extension
    "bti",  # Branch Target Identification
    "btie",  # Enhanced Branch Target Identification extension
    "cmpbr",  # Armv9.6-A base compare and branch instructions
    "cpa",  # Armv9.5-A Checked Pointer Arithmetic
    "crc",  # Armv8.0-A CRC-32 checksum instructions
    "cssc",  # Common Short Sequence Compression (CSSC) instructions
    "d128",  # Armv9.4-A 128-bit Page Table Descriptors, System Registers
    "dit",  # Armv8.4-A Data Independent Timing instructions
    "dotprod",  # dot product support
    "f16f32dot",  # Armv9.7-A Advanced SIMD half-precision dot product accumulate to...
    "f16f32mm",  # Armv9.7-A Advanced SIMD half-precision matrix multiply-accumulate...
    "f16mm",  # Armv9.7-A non-widening half-precision matrix multiply-accumulate
    "f32mm",  # Matrix Multiply FP32 Extension
    "f64mm",  # Matrix Multiply FP64 Extension
    "f8f16mm",  # Armv9.6-A FP8 to Half-Precision Matrix Multiplication
    "f8f32mm",  # Armv9.6-A FP8 to Single-Precision Matrix Multiplication
    "faminmax",  # FAMIN and FAMAX instructions
    "fcma",  # Armv8.3-A Floating-point complex number support
    "flagm",  # Armv8.4-A Flag Manipulation instructions
    "fp",  # Armv8.0-A Floating Point Extensions
    "fp16",  # half-precision floating-point data processing
    "fp16fml",  # FP16 FML instructions
    "fp8",  # FP8 instructions
    "fp8dot2",  # FP8 2-way dot instructions
    "fp8dot4",  # FP8 4-way dot instructions
    "fp8fma",  # Armv9.5-A FP8 multiply-add instructions
    "fprcvt",  # Armv9.6-A base convert instructions for SIMD&FP scalar register...
    "gcie",  # GICv5 (Generic Interrupt Controller) CPU Interface Extension
    "gcs",  # Armv9.4-A Guarded Call Stack Extension
    "hbc",  # Armv8.8-A Hinted Conditional Branches Extension
    "hinte",  # extended A64 hint instruction space
    "i8mm",  # Matrix Multiply Int8 Extension
    "ite",  # Armv9.4-A Instrumentation Extension
    "jscvt",  # Armv8.3-A JavaScript FP conversion instructions
    "ls64",  # Armv8.7-A LD64B/ST64B Accelerator Extension
    "lscp",  # Armv9.7-A Load-acquire and store-release pair extension
    "lse",  # Armv8.1-A Large System Extension (LSE) atomic instructions
    "lse128",  # Armv9.4-A 128-bit Atomic instructions
    "lsfe",  # Armv9.6-A base Atomic floating-point in-memory instructions
    "lsui",  # Armv9.6-A unprivileged load/store instructions
    "lut",  # Lookup Table instructions
    "memtag",  # Memory Tagging Extension
    "mops",  # Armv8.8-A memcpy and memset acceleration instructions
    "mops-go",  # memset acceleration granule only
    "mtetc",  # Virtual Memory Tagging Extension
    "occmo",  # Armv9.6-A Outer cacheable cache maintenance operations
    "pauth",  # Armv8.3-A Pointer Authentication extension
    "pauth-lr",  # Armv9.5-A PAC enhancements
    "pmuv3",  # Armv8.0-A PMUv3 Performance Monitors extension
    "poe2",  # Stage 1 Permission Overlays Extension 2 instructions
    "pops",  # Armv9.6-A Point Of Physical Storage (PoPS) DC instructions
    "predres",  # Armv8.5-A execution and data prediction invalidation instructions
    "predres2",  # Speculation Restriction Instruction
    "profile",  # Statistical Profiling extension
    "ras",  # Armv8.0-A Reliability, Availability and Serviceability Extensions
    "rasv2",  # Armv8.9-A Reliability, Availability and Serviceability Extensions
    "rcpc",  # support for RCPC extension
    "rcpc3",  # Armv8.9-A RCPC instructions for A64 and Advanced SIMD and...
    "rdm",  # Armv8.1-A Rounding Double Multiply Add/Subtract instructions
    "rng",  # Random Number generation instructions
    "sb",  # Armv8.5-A Speculation Barrier
    "sha2",  # SHA1 and SHA256 support
    "sha3",  # SHA512 and SHA3 support
    "simd",  # Advanced SIMD instructions
    "sm4",  # SM3 and SM4 support
    "sme",  # Scalable Matrix Extension (SME)
    "sme-b16b16",  # SME2.1 ZA-targeting non-widening BFloat16 instructions
    "sme-f16f16",  # SME non-widening Float16 instructions
    "sme-f64f64",  # Scalable Matrix Extension (SME) F64F64 instructions
    "sme-f8f16",  # Scalable Matrix Extension (SME) F8F16 instructions
    "sme-f8f32",  # Scalable Matrix Extension (SME) F8F32 instructions
    "sme-fa64",  # the full A64 instruction set in streaming SVE mode
    "sme-i16i64",  # Scalable Matrix Extension (SME) I16I64 instructions
    "sme-lutv2",  # Scalable Matrix Extension (SME) LUTv2 instructions
    "sme-mop4",  # SME Quarter-tile outer product instructions
    "sme-tmop",  # SME Structured sparsity outer product instructions.
    "sme2",  # Scalable Matrix Extension 2 (SME2) instructions
    "sme2p1",  # Scalable Matrix Extension 2.1 instructions
    "sme2p2",  # Armv9.6-A Scalable Matrix Extension 2.2 instructions
    "sme2p3",  # Armv9.7-A Scalable Matrix Extension 2.3 instructions
    "ssbs",  # Speculative Store Bypass Safe bit
    "ssve-aes",  # Armv9.6-A SVE AES support in streaming SVE mode
    "ssve-bitperm",  # Armv9.6-A SVE BitPerm support in streaming SVE mode
    "ssve-fexpa",  # SVE FEXPA instruction in Streaming SVE mode
    "ssve-fp8dot2",  # SVE2 FP8 2-way dot product instructions
    "ssve-fp8dot4",  # SVE2 FP8 4-way dot product instructions
    "ssve-fp8fma",  # SVE2 FP8 multiply-add instructions
    "sve",  # Scalable Vector Extension (SVE) instructions
    "sve-aes",  # SVE AES and quadword SVE polynomial multiply instructions
    "sve-aes2",  # Armv9.6-A SVE multi-vector AES and multi-vector quadword...
    "sve-b16b16",  # SVE2 non-widening and SME2 Z-targeting non-widening BFloat16...
    "sve-b16mm",  # Armv9.7-A SVE non-widening BFloat16 matrix multiply-accumulate
    "sve-bfscale",  # Armv9.6-A SVE BFloat16 scaling instructions
    "sve-bitperm",  # bit permutation SVE2 instructions
    "sve-f16f32mm",  # Armv9.6-A FP16 to FP32 Matrix Multiply instructions
    "sve-sha3",  # SVE SHA3 instructions
    "sve-sm4",  # SVE SM4 instructions
    "sve2",  # Scalable Vector Extension 2 (SVE2) instructions
    "sve2-aes",  # Shorthand for +sve2+sve-aes
    "sve2-bitperm",  # Shorthand for +sve2+sve-bitperm
    "sve2-sha3",  # Shorthand for +sve2+sve-sha3
    "sve2-sm4",  # Shorthand for +sve2+sve-sm4
    "sve2p1",  # Scalable Vector Extension 2.1 instructions
    "sve2p2",  # Armv9.6-A Scalable Vector Extension 2.2 instructions
    "sve2p3",  # Armv9.7-A Scalable Vector Extension 2.3 instructions
    "tev",  # TIndex Exception-like Vector instructions
    "the",  # Armv8.9-A Translation Hardening Extension
    "tlbid",  # Armv9.7-A TLBI Domains extension
    "tlbiw",  # Armv9.5-A TLBI VMALL for Dirty State
    "wfxt",  # Armv8.7-A WFET and WFIT instruction
]

# The LLVM target-feature (-mattr) name for each -march token where the two differ (the token
# is LLVM's UserVisibleName; this is the TargetFeatureName). A consumer turning the feature
# constraints into an -mattr / --target-feature string maps through this; a token not listed
# here is already its own -mattr name.
AARCH64_MARCH_TO_MATTR = {
    "fcma": "complxnum",
    "fp": "fp-armv8",
    "fp16": "fullfp16",
    "jscvt": "jsconv",
    "memtag": "mte",
    "pmuv3": "perfmon",
    "predres2": "specres2",
    "profile": "spe",
    "rng": "rand",
    "simd": "neon",
}
