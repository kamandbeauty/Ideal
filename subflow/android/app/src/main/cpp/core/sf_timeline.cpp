#include "sf_timeline.h"

#include "sf_time.h"

#include <algorithm>
#include <limits>

namespace {
constexpr sf::Micros kUnknownLengthLimit = std::numeric_limits<sf::Micros>::max() / 4;
}

namespace sf {

TimeMap::TimeMap(std::vector<TimeRange> cuts, Micros source_length_us)
    : source_length_us_(source_length_us < 0 ? 0 : source_length_us) {
  // When the source length is unknown only merge/sort, never clip.
  const Micros limit = source_length_us_ > 0 ? source_length_us_ : kUnknownLengthLimit;
  cuts_ = NormalizeRanges(std::move(cuts), limit);
  Build();
}

void TimeMap::Build() {
  kept_.clear();
  removed_us_ = 0;
  Micros cursor = 0;
  Micros dst = 0;
  for (const TimeRange& cut : cuts_) {
    if (cut.start_us > cursor) {
      kept_.push_back(Kept{cursor, cut.start_us, dst});
      dst += cut.start_us - cursor;
    }
    removed_us_ += cut.duration();
    cursor = std::max(cursor, cut.end_us);
  }
  const Micros tail_end = source_length_us_ > 0 ? source_length_us_ : cursor;
  if (tail_end > cursor) {
    kept_.push_back(Kept{cursor, tail_end, dst});
    dst += tail_end - cursor;
  }
  new_length_us_ = dst;
}

bool TimeMap::IsRemoved(Micros source_us) const {
  for (const TimeRange& cut : cuts_) {
    if (source_us >= cut.start_us && source_us < cut.end_us) return true;
  }
  return false;
}

Micros TimeMap::Map(Micros source_us) const {
  if (source_us <= 0) return 0;
  for (const Kept& k : kept_) {
    if (source_us < k.src_end_us) {
      const Micros offset = std::max<Micros>(0, source_us - k.src_start_us);
      return k.dst_start_us + offset;
    }
  }
  return new_length_us_;
}

bool TimeMap::MapRange(TimeRange source, TimeRange* out) const {
  if (out == nullptr) return false;
  const std::vector<TimeRange> pieces = MapRangeSplit(source);
  if (pieces.empty()) return false;
  out->start_us = pieces.front().start_us;
  out->end_us = pieces.back().end_us;
  return out->end_us > out->start_us;
}

std::vector<TimeRange> TimeMap::MapRangeSplit(TimeRange source) const {
  std::vector<TimeRange> out;
  if (source.end_us <= source.start_us) return out;
  for (const Kept& k : kept_) {
    const Micros s = std::max(source.start_us, k.src_start_us);
    const Micros e = std::min(source.end_us, k.src_end_us);
    if (e <= s) continue;
    TimeRange mapped;
    mapped.start_us = k.dst_start_us + (s - k.src_start_us);
    mapped.end_us = k.dst_start_us + (e - k.src_start_us);
    if (mapped.end_us > mapped.start_us) out.push_back(mapped);
  }
  return out;
}

std::vector<Segment> RemapSegments(const std::vector<Segment>& segments, const TimeMap& map,
                                   Micros min_duration_us) {
  std::vector<Segment> out;
  out.reserve(segments.size());
  for (const Segment& segment : segments) {
    const std::vector<TimeRange> pieces =
        map.MapRangeSplit(TimeRange{segment.start_us, segment.end_us});
    if (pieces.empty()) continue;

    for (const TimeRange& piece : pieces) {
      if (piece.duration() < min_duration_us) continue;
      Segment s;
      s.start_us = piece.start_us;
      s.end_us = piece.end_us;
      s.text = segment.text;
      s.style = segment.style;
      for (const Word& w : segment.words) {
        const std::vector<TimeRange> wp =
            map.MapRangeSplit(TimeRange{w.start_us, w.end_us});
        if (wp.empty()) continue;
        Word nw;
        nw.start_us = std::max(wp.front().start_us, piece.start_us);
        nw.end_us = std::min(wp.back().end_us, piece.end_us);
        nw.text = w.text;
        if (nw.end_us > nw.start_us) s.words.push_back(nw);
      }
      out.push_back(std::move(s));
    }
  }
  std::stable_sort(out.begin(), out.end(), [](const Segment& a, const Segment& b) {
    return a.start_us < b.start_us;
  });
  return out;
}

}  // namespace sf
