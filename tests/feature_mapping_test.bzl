load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//cpu/x86_64:x86_64_private.bzl", "X86_64_EXTRA_FEATURES", "X86_64_LLVM_FEATURES")
load(
    "//private:feature_mapping.bzl",
    "aarch64_feature_constraint_names",
    "validation_for_tests",
    "x86_64_feature_constraint_names",
)

visibility("private")

def _report():
    return {
        "cpu": "generic",
        "features": {name: False for name in X86_64_LLVM_FEATURES + ["cmov", "64bit", "cx8"]},
        "extras": {name: False for name in X86_64_EXTRA_FEATURES},
    }

def _explicit_negatives_test(env):
    report = _report()
    report["features"]["x87"] = True
    report["features"]["avx512f"] = True
    report["features"]["avx512bf16"] = True
    report["extras"]["rdtscp"] = True
    names = x86_64_feature_constraint_names(report)
    env.expect.that_int(len(names)).equals(len(X86_64_LLVM_FEATURES) + len(X86_64_EXTRA_FEATURES))
    for name in ["x87", "avx512bf16", "rdtscp"]:
        env.expect.that_bool(name + "_available" in names).equals(True)
    for name in ["sse", "crc32", "push2pop2", "ppx", "ermsb"]:
        env.expect.that_bool(name + "_unavailable" in names).equals(True)
    for name in ["cmov", "64bit", "cx8"]:
        env.expect.that_bool(name + "_available" in names).equals(False)
        env.expect.that_bool(name + "_unavailable" in names).equals(False)

def _missing_feature_test(env):
    report = _report()
    report["features"].pop("crc32")
    env.expect.that_str(validation_for_tests.report_error(report)).contains("missing [crc32]")

def _unknown_feature_test(env):
    report = _report()
    report["features"]["sse4_2"] = True
    env.expect.that_str(validation_for_tests.report_error(report)).contains("unknown [sse4_2]")

def _malformed_report_test(env):
    for report in [None, []]:
        env.expect.that_str(validation_for_tests.report_error(report)).contains("JSON object")
    report = _report()
    report["features"]["avx"] = 1
    env.expect.that_str(validation_for_tests.report_error(report)).contains("must be a boolean")
    report = _report()
    report["extras"] = []
    env.expect.that_str(validation_for_tests.report_error(report)).contains("must be a dictionary")
    report = _report()
    report["cpu"] = ""
    env.expect.that_str(validation_for_tests.report_error(report)).contains("nonempty cpu")

def _missing_prerequisite_test(env):
    report = _report()
    report["features"]["avx10.2"] = True
    env.expect.that_str(validation_for_tests.report_error(report)).contains("requires avx10.1")

def _aarch64_report(features):
    # The aarch64 detector reports only the features it positively detected.
    return {"cpu": "", "features": {name: True for name in features}}

def _aarch64_available_only_test(env):
    report = _aarch64_report(["fp", "simd", "sve", "sve2", "sme", "sme2"])
    names = aarch64_feature_constraint_names(report)
    for name in ["fp", "simd", "sve2", "sme2"]:
        env.expect.that_bool(name + "_available" in names).equals(True)

    # Sparse: an undetected feature is absent entirely, never reported unavailable.
    env.expect.that_bool("aes_available" in names).equals(False)
    for name in names:
        env.expect.that_bool(name.endswith("_available")).equals(True)

def _aarch64_empty_cpu_ok_test(env):
    # The aarch64 detector reports an empty model for an unknown CPU; that must validate (x86-64
    # requires a nonempty cpu).
    report = _aarch64_report(["fp", "simd"])
    env.expect.that_bool(validation_for_tests.aarch64_report_error(report) == None).equals(True)

def _aarch64_unknown_feature_test(env):
    report = _aarch64_report(["fp", "not_a_token"])
    env.expect.that_str(validation_for_tests.aarch64_report_error(report)).contains("unknown [not_a_token]")

def _aarch64_malformed_report_test(env):
    report = _aarch64_report(["fp"])
    report["features"]["sve"] = 1
    env.expect.that_str(validation_for_tests.aarch64_report_error(report)).contains("must be a boolean")
    env.expect.that_str(validation_for_tests.aarch64_report_error({"cpu": "", "features": []})).contains("must be a dictionary")
    env.expect.that_str(validation_for_tests.aarch64_report_error({"cpu": 5, "features": {}})).contains("string cpu")

def feature_mapping_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _explicit_negatives_test,
            _missing_feature_test,
            _unknown_feature_test,
            _malformed_report_test,
            _missing_prerequisite_test,
            _aarch64_available_only_test,
            _aarch64_empty_cpu_ok_test,
            _aarch64_unknown_feature_test,
            _aarch64_malformed_report_test,
        ],
    )
