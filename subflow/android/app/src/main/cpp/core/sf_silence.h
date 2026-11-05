// Energy based voice-activity detection used by the "remove silence" feature.
// We deliberately do not ship a heavyweight ML VAD: an RMS/dBFS gate with
// hysteresis is what editors such as Descript-class tools use for the first
// pass, it is fully deterministic and it can run on the Kotlin side over PCM
// blocks decoded by Media3 without extra native dependencies.
#pragma once

#include <vector>

#include "sf_common.h"

namespace sf {

struct SilenceConfig {
  // Everything below this level is considered non-speech.
  double threshold_dbfs = -38.0;
  // A pause must be at least this long to be removable.
  Micros min_silence_us = 350 * kUsPerMs;
  // Shorter bursts of sound are treated as noise, not as speech.
  Micros min_speech_us = 120 * kUsPerMs;
  // Kept on both sides of speech so cuts never clip a consonant.
  Micros pad_us = 60 * kUsPerMs;
  // Analysis window / hop. 20 ms window with 10 ms hop is frame accurate enough
  // for subtitles and cheap on low-end ARM64 devices.
  int window_ms = 20;
};

struct SilenceResult {
  std::vector<TimeRange> silent;      // removable ranges, sorted, non-overlapping
  Micros analysed_us = 0;
  double silent_ratio = 0.0;          // 0..1
};

// `mono` must be mono float32 in [-1, 1] at `sample_rate` Hz.
// Returns silent ranges in source-time. Never mutates the input.
SilenceResult DetectSilence(const float* mono, std::size_t frame_count, int sample_rate,
                            const SilenceConfig& config);

}  // namespace sf
