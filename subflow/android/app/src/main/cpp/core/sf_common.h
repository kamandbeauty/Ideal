// SubFlow native core - shared primitives.
// Every timestamp in the whole product is an integer number of microseconds.
// No floating point is allowed to own a timestamp: rounding errors at 29.97fps
// would otherwise desynchronise subtitles from video over a long timeline.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace sf {

using Micros = std::int64_t;

constexpr Micros kUsPerMs = 1000;
constexpr Micros kUsPerSec = 1000000;
constexpr Micros kUsPerMin = 60 * kUsPerSec;

struct TimeRange {
  Micros start_us = 0;
  Micros end_us = 0;

  Micros duration() const { return end_us > start_us ? end_us - start_us : 0; }
  bool empty() const { return end_us <= start_us; }
};

inline bool operator==(const TimeRange& a, const TimeRange& b) {
  return a.start_us == b.start_us && a.end_us == b.end_us;
}

// A single timed word. Phase 2 fills these from whisper.cpp token timings and
// Phase 4 uses them for karaoke / word-highlight effects.
struct Word {
  Micros start_us = 0;
  Micros end_us = 0;
  std::string text;
};

// One subtitle line. `style` is the ASS style name; empty means project default.
struct Segment {
  Micros start_us = 0;
  Micros end_us = 0;
  std::string text;
  std::string style;
  std::vector<Word> words;

  Micros duration() const { return end_us > start_us ? end_us - start_us : 0; }
};

}  // namespace sf
