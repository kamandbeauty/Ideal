// Timeline surgery used by "remove silence".
//
// One TimeMap is built from the user-approved cuts and then used for *every*
// timed object (subtitles, words, watermarks, effect windows, audio fades) so
// nothing can drift out of sync when a cut is applied.
#pragma once

#include <vector>

#include "sf_common.h"

namespace sf {

class TimeMap {
 public:
  // `source_length_us` <= 0 means "unknown"; cuts are then not clipped.
  TimeMap() = default;
  TimeMap(std::vector<TimeRange> cuts, Micros source_length_us);

  bool empty() const { return cuts_.empty(); }
  const std::vector<TimeRange>& cuts() const { return cuts_; }

  // True when `source_us` falls inside a removed range.
  bool IsRemoved(Micros source_us) const;

  // Maps a kept source-time to the new timeline. Timestamps that pointed into a
  // removed range collapse onto the new start of the next kept fragment.
  Micros Map(Micros source_us) const;

  // Maps a range. Returns false when the range was entirely removed, in which
  // case nothing should be drawn / played.
  bool MapRange(TimeRange source, TimeRange* out) const;

  // Maps a range by splitting it into the kept fragments that survive.
  std::vector<TimeRange> MapRangeSplit(TimeRange source) const;

  Micros source_length_us() const { return source_length_us_; }
  Micros new_length_us() const { return new_length_us_; }
  Micros removed_us() const { return removed_us_; }

 private:
  // kept_[i] = [source start, source end, new start]
  struct Kept {
    Micros src_start_us;
    Micros src_end_us;
    Micros dst_start_us;
  };

  void Build();

  std::vector<TimeRange> cuts_;
  Micros source_length_us_ = 0;
  Micros new_length_us_ = 0;
  Micros removed_us_ = 0;
  std::vector<Kept> kept_;
};

// Rewrites subtitle segments through `map`:
//  * a segment split by a cut becomes several segments (text is preserved),
//  * segments entirely inside a cut are dropped,
//  * words inside a cut are dropped, partially clipped words are clamped,
//  * degenerate results (end <= start) are dropped.
std::vector<Segment> RemapSegments(const std::vector<Segment>& segments, const TimeMap& map,
                                   Micros min_duration_us = 1);

}  // namespace sf
