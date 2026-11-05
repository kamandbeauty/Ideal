#include "sf_time.h"

#include <algorithm>
#include <cmath>
#include <cstdio>

namespace sf {
namespace {

std::int64_t RoundHalfAwayFromZero(double v) {
  return v >= 0.0 ? static_cast<std::int64_t>(v + 0.5) : static_cast<std::int64_t>(v - 0.5);
}

}  // namespace

Micros ClampMicros(Micros value, Micros lo, Micros hi) {
  if (value < lo) return lo;
  if (value > hi) return hi;
  return value;
}

Micros MicrosFromMs(double ms) { return RoundHalfAwayFromZero(ms * 1000.0); }

Micros MicrosFromSeconds(double seconds) { return RoundHalfAwayFromZero(seconds * 1000000.0); }

Micros FramesToMicros(std::int64_t frames, double fps) {
  if (fps <= 0.0) return 0;
  return RoundHalfAwayFromZero(static_cast<double>(frames) * 1000000.0 / fps);
}

std::int64_t MicrosToFrames(Micros us, double fps) {
  if (fps <= 0.0 || us <= 0) return 0;
  return static_cast<std::int64_t>(std::llround(static_cast<double>(us) * fps / 1000000.0));
}

std::string FormatSrtTime(Micros us) {
  const Micros clamped = us < 0 ? 0 : us;
  const Micros total_ms = clamped / 1000;  // truncation, SRT has no sub-ms field
  const Micros ms = total_ms % 1000;
  const Micros total_s = total_ms / 1000;
  const Micros s = total_s % 60;
  const Micros m = (total_s / 60) % 60;
  const Micros h = total_s / 3600;
  char buf[32];
  std::snprintf(buf, sizeof(buf), "%02lld:%02lld:%02lld,%03lld",
                static_cast<long long>(h), static_cast<long long>(m),
                static_cast<long long>(s), static_cast<long long>(ms));
  return std::string(buf);
}

std::string FormatAssTime(Micros us) {
  Micros clamped = us < 0 ? 0 : us;
  // ASS stores centiseconds and is conventionally rounded (not truncated),
  // otherwise 1.999s and 1.5s would collapse onto the same timestamp.
  const Micros total_cs = (clamped + 5000) / 10000;
  const Micros cs = total_cs % 100;
  const Micros total_s = total_cs / 100;
  const Micros s = total_s % 60;
  const Micros m = (total_s / 60) % 60;
  const Micros h = total_s / 3600;
  char buf[32];
  std::snprintf(buf, sizeof(buf), "%lld:%02lld:%02lld.%02lld", static_cast<long long>(h),
                static_cast<long long>(m), static_cast<long long>(s),
                static_cast<long long>(cs));
  return std::string(buf);
}

std::vector<TimeRange> NormalizeRanges(std::vector<TimeRange> ranges, Micros limit) {
  std::vector<TimeRange> out;
  for (const TimeRange& r : ranges) {
    TimeRange c;
    c.start_us = ClampMicros(r.start_us, 0, limit < 0 ? 0 : limit);
    c.end_us = ClampMicros(r.end_us, 0, limit < 0 ? 0 : limit);
    if (c.duration() <= 0) continue;
    out.push_back(c);
  }
  std::sort(out.begin(), out.end(), [](const TimeRange& a, const TimeRange& b) {
    if (a.start_us != b.start_us) return a.start_us < b.start_us;
    return a.end_us < b.end_us;
  });
  std::vector<TimeRange> merged;
  for (const TimeRange& r : out) {
    if (!merged.empty() && r.start_us <= merged.back().end_us) {
      if (r.end_us > merged.back().end_us) merged.back().end_us = r.end_us;
    } else {
      merged.push_back(r);
    }
  }
  return merged;
}

Micros TotalLength(const std::vector<TimeRange>& ranges) {
  Micros total = 0;
  for (const TimeRange& r : ranges) total += r.duration();
  return total;
}

}  // namespace sf
