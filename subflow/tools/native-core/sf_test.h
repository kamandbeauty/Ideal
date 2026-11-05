// Minimal dependency-free test harness. The native core is compiled and tested
// on the host with g++ (see Makefile) so the algorithms that drive subtitle
// timing and export quality are verified without an Android device.
#pragma once

#include <cmath>
#include <cstdio>
#include <string>

namespace sftest {

inline int& Failures() {
  static int failures = 0;
  return failures;
}
inline int& Checks() {
  static int checks = 0;
  return checks;
}

inline void Report(bool ok, const char* expr, const char* file, int line,
                   const std::string& detail) {
  ++Checks();
  if (ok) return;
  ++Failures();
  std::printf("  FAIL %s:%d  %s", file, line, expr);
  if (!detail.empty()) std::printf("  [%s]", detail.c_str());
  std::printf("\n");
}

}  // namespace sftest

#define SF_CHECK(expr)                                                        \
  ::sftest::Report(static_cast<bool>(expr), #expr, __FILE__, __LINE__, "")

#define SF_CHECK_MSG(expr, detail)                                            \
  ::sftest::Report(static_cast<bool>(expr), #expr, __FILE__, __LINE__, detail)

#define SF_CHECK_EQ_INT(actual, expected)                                     \
  ::sftest::Report((actual) == (expected), #actual " == " #expected, __FILE__, \
                   __LINE__,                                                 \
                   std::to_string(static_cast<long long>(actual)) + " vs " +  \
                       std::to_string(static_cast<long long>(expected)))

#define SF_CHECK_EQ_STR(actual, expected)                                     \
  ::sftest::Report((actual) == (expected), #actual " == " #expected, __FILE__, \
                   __LINE__, std::string(actual) + " vs " + std::string(expected))

#define SF_CHECK_NEAR(actual, expected, tolerance)                            \
  ::sftest::Report(std::fabs(static_cast<double>(actual) -                    \
                             static_cast<double>(expected)) <=                \
                       (tolerance),                                           \
                   #actual " ~= " #expected, __FILE__, __LINE__,              \
                   std::to_string(static_cast<double>(actual)) + " vs " +     \
                       std::to_string(static_cast<double>(expected)))
