#include "sf_silence.h"

#include "sf_time.h"

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace sf {
namespace {

double RmsToDbfs(double rms) {
  constexpr double kFloor = 1e-9;
  if (rms <= kFloor) return -180.0;
  return 20.0 * std::log10(rms);
}

}  // namespace

SilenceResult DetectSilence(const float* mono, std::size_t frame_count, int sample_rate,
                            const SilenceConfig& config) {
  SilenceResult result;
  if (mono == nullptr || frame_count == 0 || sample_rate <= 0) return result;

  const Micros duration_us = static_cast<Micros>(
      (static_cast<std::int64_t>(frame_count) * kUsPerSec) / sample_rate);
  result.analysed_us = duration_us;

  std::size_t window = static_cast<std::size_t>(sample_rate * config.window_ms / 1000);
  if (window < 32) window = 32;
  std::size_t hop = window / 2;
  if (hop == 0) hop = 1;

  // 1. Per-hop classification with hysteresis: opening needs the tone to be
  //    clearly above the gate, closing is allowed right at the gate.
  struct Block {
    Micros start_us;
    Micros end_us;
    bool speech;
  };
  std::vector<Block> blocks;
  const double open_db = config.threshold_dbfs + 3.0;
  const double close_db = config.threshold_dbfs - 1.0;
  bool in_speech = false;

  for (std::size_t offset = 0; offset < frame_count; offset += hop) {
    const std::size_t n = std::min(window, frame_count - offset);
    double sum_sq = 0.0;
    for (std::size_t i = 0; i < n; ++i) {
      const double v = mono[offset + i];
      sum_sq += v * v;
    }
    const double rms = std::sqrt(sum_sq / static_cast<double>(n));
    const double db = RmsToDbfs(rms);

    if (!in_speech && db >= open_db) {
      in_speech = true;
    } else if (in_speech && db < close_db) {
      in_speech = false;
    }

    const Micros start_us = static_cast<Micros>(
        (static_cast<std::int64_t>(offset) * kUsPerSec) / sample_rate);
    const Micros end_us = static_cast<Micros>(
        (static_cast<std::int64_t>(offset + n) * kUsPerSec) / sample_rate);
    blocks.push_back(Block{start_us, end_us, in_speech});
  }

  // 2. Merge speech blocks that are separated by less than min_silence_us, so a
  //    short breath does not produce two razor-thin cuts.
  std::vector<TimeRange> speech;
  for (const Block& b : blocks) {
    if (!b.speech) continue;
    if (!speech.empty() && b.start_us - speech.back().end_us < config.min_silence_us) {
      if (b.end_us > speech.back().end_us) speech.back().end_us = b.end_us;
    } else {
      speech.push_back(TimeRange{b.start_us, b.end_us});
    }
  }

  // 3. Drop speech bursts that are too short to be a word (clicks, pops, noise).
  std::vector<TimeRange> stable;
  for (const TimeRange& r : speech) {
    if (r.duration() >= config.min_speech_us) {
      stable.push_back(r);
    } else if (!stable.empty()) {
      // Absorb the burst into the previous speech block instead of leaving a gap.
      if (r.end_us > stable.back().end_us) stable.back().end_us = r.end_us;
    }
  }

  // 4. Complement => silence, padded so consonants are not clipped.
  std::vector<TimeRange> silence;
  Micros cursor = 0;
  for (const TimeRange& r : stable) {
    TimeRange gap{cursor, r.start_us};
    if (gap.duration() > 0) silence.push_back(gap);
    cursor = std::max(cursor, r.end_us);
  }
  if (cursor < duration_us) silence.push_back(TimeRange{cursor, duration_us});

  std::vector<TimeRange> padded;
  for (const TimeRange& gap : silence) {
    TimeRange p{gap.start_us + config.pad_us, gap.end_us - config.pad_us};
    if (p.start_us < 0) p.start_us = 0;
    if (p.end_us > duration_us) p.end_us = duration_us;
    if (p.duration() >= config.min_silence_us) padded.push_back(p);
  }

  result.silent = NormalizeRanges(padded, duration_us);
  if (duration_us > 0) {
    result.silent_ratio =
        static_cast<double>(TotalLength(result.silent)) / static_cast<double>(duration_us);
  }
  return result;
}

}  // namespace sf
