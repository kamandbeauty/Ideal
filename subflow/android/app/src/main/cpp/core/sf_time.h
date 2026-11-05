#pragma once

#include <string>
#include <vector>

#include "sf_common.h"

namespace sf {

Micros ClampMicros(Micros value, Micros lo, Micros hi);

// Deterministic float -> microsecond conversion (round half away from zero).
Micros MicrosFromMs(double ms);
Micros MicrosFromSeconds(double seconds);

Micros FramesToMicros(std::int64_t frames, double fps);
std::int64_t MicrosToFrames(Micros us, double fps);

// SRT: "HH:MM:SS,mmm"   ASS: "H:MM:SS.cc" (centiseconds, 1 digit hour)
std::string FormatSrtTime(Micros us);
std::string FormatAssTime(Micros us);

// Sorts, merges overlapping/adjacent ranges, clips to [0, limit] and drops empties.
std::vector<TimeRange> NormalizeRanges(std::vector<TimeRange> ranges, Micros limit);

Micros TotalLength(const std::vector<TimeRange>& ranges);

}  // namespace sf
