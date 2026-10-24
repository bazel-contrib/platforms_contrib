// Host aarch64 CPU feature detector. Prints a JSON report {cpu, features} on stdout, where each
// feature is a platforms_contrib -march token (as in AARCH64_FEATURES) the host has. The report is
// sparse: only detected features appear, as {token: true}. It has no LLVM dependency.
//
//   * Linux: Google cpu_features' GetAarch64Info() reads HWCAP via getauxval, the same
//     kernel-sanitised bits LLVM's getHostCPUFeatures() reads. The model is the MIDR
//     (implementer, part) mapped through prebuilt/aarch64_cpu_models.inc, generated from LLVM's
//     getHostCPUNameForARM.
//
//   * macOS: the hw.optional.arm.FEAT_* sysctls (macOS 12+; macOS 11 only has the older
//     hw.optional.armv8_* keys, which are not read). LLVM has no hardware feature read for Darwin
//     AArch64 and cpu_features' Darwin backend stops at FEAT_BTI, so neither reports SVE or SME. The
//     model is the "Apple M<N>" brand string mapped to apple-m<N> for the generations LLVM knows.
//
// An unlisted feature is never reported (a platform must not claim a capability that was not
// positively detected), and an unknown CPU yields an empty model. Other operating systems are not
// supported.
//
// The prebuilts workflow cross-compiles this for linux_aarch64 and macos_aarch64. //host:native uses
// it once a released binary is listed in //private:prebuilts.bzl's PREBUILT_DETECTORS; add an entry
// only for a binary that has been run on hardware for that OS.

#include <cstddef>
#include <cstdio>
#include <string>
#include <vector>

#ifdef __APPLE__
#include <cstdlib>
#include <cstring>
#include <sys/sysctl.h>
#elif defined(__linux__)
#include "cpuinfo_aarch64.h"
#include "prebuilt/aarch64_cpu_models.inc"
#else
#error "unsupported operating system"
#endif

namespace {

#ifdef __APPLE__

bool SysctlArmFeature(const char *feature) {
  int value = 0;
  size_t size = sizeof(value);
  char key[160];
  std::snprintf(key, sizeof(key), "hw.optional.arm.%s", feature);
  return sysctlbyname(key, &value, &size, nullptr, 0) == 0 && value != 0;
}

std::vector<const char *> DetectFeatures() {
  // hw.optional.arm.FEAT_* -> -march token. An absent sysctl reads as 0.
  static const struct {
    const char *feature;
    const char *token;
  } kFeatures[] = {
      {"FEAT_CRC32", "crc"},
      {"FEAT_LSE", "lse"},
      {"FEAT_LSE128", "lse128"},
      {"FEAT_RDM", "rdm"},
      {"FEAT_FP16", "fp16"},
      {"FEAT_FHM", "fp16fml"},
      {"FEAT_DotProd", "dotprod"},
      {"FEAT_JSCVT", "jscvt"},
      {"FEAT_FCMA", "fcma"},
      {"FEAT_LRCPC", "rcpc"},
      {"FEAT_LRCPC3", "rcpc3"},
      {"FEAT_FlagM", "flagm"},
      {"FEAT_SB", "sb"},
      {"FEAT_SSBS", "ssbs"},
      {"FEAT_PAuth", "pauth"},
      {"FEAT_DIT", "dit"},
      {"FEAT_I8MM", "i8mm"},
      {"FEAT_BF16", "bf16"},
      {"FEAT_BTI", "bti"},
      {"FEAT_WFxT", "wfxt"},
      {"FEAT_CSSC", "cssc"},
      {"FEAT_MOPS", "mops"},
      {"FEAT_HBC", "hbc"},
      {"FEAT_FAMINMAX", "faminmax"},
      {"FEAT_LUT", "lut"},
      {"FEAT_SVE", "sve"},
      {"FEAT_SVE2", "sve2"},
      {"FEAT_SVE2p1", "sve2p1"},
      {"FEAT_SME", "sme"},
      {"FEAT_SME2", "sme2"},
      {"FEAT_SME2p1", "sme2p1"},
      {"FEAT_SME_F64F64", "sme-f64f64"},
      {"FEAT_SME_I16I64", "sme-i16i64"},
      {"FEAT_SME_B16B16", "sme-b16b16"},
      {"FEAT_SME_F16F16", "sme-f16f16"},
  };
  std::vector<const char *> tokens;
  tokens.push_back("fp");    // Armv8-A mandates FP and
  tokens.push_back("simd");  // Advanced SIMD for userspace.
  for (const auto &entry : kFeatures)
    if (SysctlArmFeature(entry.feature))
      tokens.push_back(entry.token);
  // LLVM bundles two FEAT_* under one token for the crypto extensions; require both, since claiming
  // the token on a chip that has only one half miscompiles.
  static const struct {
    const char *token;
    const char *first;
    const char *second;
  } kBundles[] = {
      {"aes", "FEAT_AES", "FEAT_PMULL"},
      {"sha2", "FEAT_SHA1", "FEAT_SHA256"},
      {"sha3", "FEAT_SHA3", "FEAT_SHA512"},
      {"sm4", "FEAT_SM3", "FEAT_SM4"},
  };
  for (const auto &bundle : kBundles)
    if (SysctlArmFeature(bundle.first) && SysctlArmFeature(bundle.second))
      tokens.push_back(bundle.token);
  return tokens;
}

std::string DetectModel() {
  // machdep.cpu.brand_string is "Apple M<N> [Pro|Max|Ultra]"; map the generation to the LLVM -mcpu
  // name for the generations LLVM knows (M1..M4). An unknown brand yields an empty model.
  char brand[256];
  std::size_t size = sizeof(brand);
  if (sysctlbyname("machdep.cpu.brand_string", brand, &size, nullptr, 0) != 0)
    return "";
  const char *apple = std::strstr(brand, "Apple M");
  if (!apple)
    return "";
  int generation = std::atoi(apple + 7);  // the digits right after "Apple M"
  if (generation >= 1 && generation <= 4)
    return "apple-m" + std::to_string(generation);
  return "";
}

#elif defined(__linux__)

std::vector<const char *> DetectFeatures() {
  const cpu_features::Aarch64Features f = cpu_features::GetAarch64Info().features;
  std::vector<const char *> tokens;
  const auto add = [&tokens](bool present, const char *token) {
    if (present)
      tokens.push_back(token);
  };
  add(f.fp, "fp");
  add(f.asimd, "simd");
  // LLVM bundles two FEAT_* under one token for the crypto extensions (aes = AES+PMULL, sha2 =
  // SHA1+SHA256, sha3 = SHA3+SHA512, sm4 = SM3+SM4) and HWCAP has a bit per half, so require both.
  // ssbs (SSBS+SSBS2) and memtag (MTE+MTE2) are bundles too, but the kernel sets their single HWCAP
  // only for the complete version, so one bit suffices for those.
  add(f.aes && f.pmull, "aes");
  add(f.sha1 && f.sha2, "sha2");
  add(f.sha3 && f.sha512, "sha3");
  add(f.sm3 && f.sm4, "sm4");
  add(f.crc32, "crc");
  add(f.atomics, "lse");
  add(f.lse128, "lse128");
  add(f.asimdrdm, "rdm");
  add(f.fphp || f.asimdhp, "fp16");
  add(f.asimdfhm, "fp16fml");
  add(f.asimddp, "dotprod");
  add(f.jscvt, "jscvt");
  add(f.fcma, "fcma");
  add(f.lrcpc, "rcpc");
  add(f.lrcpc3, "rcpc3");
  add(f.flagm, "flagm");
  add(f.sb, "sb");
  add(f.ssbs, "ssbs");
  add(f.paca && f.pacg, "pauth");
  add(f.dit, "dit");
  add(f.mte, "memtag");
  add(f.rng, "rng");
  add(f.i8mm, "i8mm");
  add(f.bf16, "bf16");
  add(f.bti, "bti");
  add(f.wfxt, "wfxt");
  add(f.cssc, "cssc");
  add(f.mops, "mops");
  add(f.hbc, "hbc");
  add(f.faminmax, "faminmax");
  add(f.lut, "lut");
  add(f.sve, "sve");
  add(f.sve2, "sve2");
  add(f.sve2p1, "sve2p1");
  add(f.sveaes, "sve2-aes");
  add(f.svebitperm, "sve2-bitperm");
  add(f.svesha3, "sve2-sha3");
  add(f.svesm4, "sve2-sm4");
  add(f.sveb16b16, "sve-b16b16");
  add(f.sme, "sme");
  add(f.sme2, "sme2");
  add(f.sme2p1, "sme2p1");
  add(f.smef64f64, "sme-f64f64");
  add(f.smei16i64, "sme-i16i64");
  add(f.smeb16b16, "sme-b16b16");
  add(f.smef16f16, "sme-f16f16");
  return tokens;
}

std::string DetectModel() {
  // Map the host MIDR (implementer, part) to an LLVM -mcpu name via the generated table. An unlisted
  // CPU yields an empty model, exactly like LLVM's getHostCPUNameForARM default ("generic" there).
  const cpu_features::Aarch64Info info = cpu_features::GetAarch64Info();
  for (const auto &model : kAarch64CpuModels)
    if (model.implementer == static_cast<unsigned>(info.implementer) &&
        model.part == static_cast<unsigned>(info.part))
      return model.mcpu;
  return "";
}

#endif

} // namespace

int main() {
  const std::vector<const char *> features = DetectFeatures();
  // The model is an LLVM -mcpu name (letters, digits, '-'), so it needs no JSON escaping.
  const std::string model = DetectModel();
  std::printf("{\"cpu\":\"%s\",\"features\":{", model.c_str());
  for (std::size_t i = 0; i < features.size(); ++i)
    std::printf("%s\"%s\":true", i == 0 ? "" : ",", features[i]);
  std::fputs("}}\n", stdout);
  return 0;
}
