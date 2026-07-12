// Prints every CPU feature known to the cpu_features library
// (https://github.com/google/cpu_features), one per line, prefixed with "+" if it is available on
// the host machine and "-" if not:
//
//   +sse4_2
//   -avx512f
//   ...
//
// Feature names are the enum names used by cpu_features (see feature_mapping.bzl in //private
// for the mapping to constraint values).

#include <stdio.h>

#include "cpuinfo_x86.h"

int main(void) {
  const X86Info info = GetX86Info();
  for (int i = 0; i < X86_LAST_; ++i) {
    printf("%c%s\n",
           GetX86FeaturesEnumValue(&info.features, (X86FeaturesEnum)i) ? '+' : '-',
           GetX86FeaturesEnumName((X86FeaturesEnum)i));
  }
  return 0;
}
