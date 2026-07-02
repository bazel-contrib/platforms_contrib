// A minimal, highly portable program that prints the architecture of and the CPU features
// available on the host machine, one item per line:
//
//   arch:x86_64
//   feature:sse4_2
//   feature:avx2
//   ...
//
// Feature names are the enum names used by the cpu_features library (see feature_mapping.bzl in
// //host/private for the mapping to constraint values). The program is intentionally portable
// C99 that is self-contained apart from cpu_features, so that it cross-compiles statically for
// every supported host platform.

#include <stdio.h>

#include "cpu_features_macros.h"

#if defined(CPU_FEATURES_ARCH_X86)
#include "cpuinfo_x86.h"
#elif defined(CPU_FEATURES_ARCH_AARCH64)
#include "cpuinfo_aarch64.h"
#endif

int main(void) {
#if defined(CPU_FEATURES_ARCH_X86_64)
  puts("arch:x86_64");
#elif defined(CPU_FEATURES_ARCH_X86)
  puts("arch:x86_32");
#elif defined(CPU_FEATURES_ARCH_AARCH64)
  puts("arch:aarch64");
#else
  puts("arch:unknown");
#endif

#if defined(CPU_FEATURES_ARCH_X86)
  const X86Info info = GetX86Info();
  for (int i = 0; i < X86_LAST_; ++i) {
    if (GetX86FeaturesEnumValue(&info.features, (X86FeaturesEnum)i)) {
      printf("feature:%s\n", GetX86FeaturesEnumName((X86FeaturesEnum)i));
    }
  }
#elif defined(CPU_FEATURES_ARCH_AARCH64)
  const Aarch64Info info = GetAarch64Info();
  for (int i = 0; i < AARCH64_LAST_; ++i) {
    if (GetAarch64FeaturesEnumValue(&info.features, (Aarch64FeaturesEnum)i)) {
      printf("feature:%s\n", GetAarch64FeaturesEnumName((Aarch64FeaturesEnum)i));
    }
  }
#endif

  return 0;
}
