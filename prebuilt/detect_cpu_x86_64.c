// Prints every cpu_features enum name on its own line, prefixed with "+" if available or "-"
// otherwise (e.g. "+sse4_2", "-avx512f"). See //private:feature_mapping.bzl for constraint mappings.

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
