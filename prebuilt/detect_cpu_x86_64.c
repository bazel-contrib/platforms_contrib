// Prints the x86-64 CPU features available on the host machine as reported by the cpu_features
// library (https://github.com/google/cpu_features), one per line:
//
//   sse4_2
//   avx2
//   ...
//
// Feature names are the enum names used by cpu_features (see feature_mapping.bzl in //private
// for the mapping to constraint values).

#include <stdio.h>

#include "cpuinfo_x86.h"

int main(void) {
  const X86Info info = GetX86Info();
  for (int i = 0; i < X86_LAST_; ++i) {
    if (GetX86FeaturesEnumValue(&info.features, (X86FeaturesEnum)i)) {
      printf("%s\n", GetX86FeaturesEnumName((X86FeaturesEnum)i));
    }
  }
  return 0;
}
