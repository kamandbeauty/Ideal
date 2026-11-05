// Export planning. This is the single place that decides the output geometry,
// frame rate, bitrate and whether a re-encode is even necessary.
//
// Non-negotiable product rules encoded here:
//   * Original Quality never silently changes resolution, aspect or fps.
//   * Nothing is upscaled unless the user explicitly asked for it, and even
//     then the plan carries a warning saying the extra pixels are interpolated.
//   * When no picture change is requested the plan is a passthrough (stream
//     copy) so the file is never re-compressed "just because".
//   * Bitrate is derived from pixels-per-second of the *source*, so a 4K source
//     is not squeezed into a 1080p bitrate budget.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "sf_common.h"

namespace sf {

enum class QualityPreset {
  kOriginal = 0,
  k480p = 480,
  k720p = 720,
  k1080p = 1080,
  k1440p = 1440,
  k2160p = 2160,
};

enum class VideoCodec { kH264, kHevc };

struct SourceInfo {
  int width = 0;
  int height = 0;              // display height (rotation already applied)
  int rotation_degrees = 0;
  double fps = 30.0;
  std::int64_t bitrate_bps = 0;  // 0 => unknown
  VideoCodec codec = VideoCodec::kH264;
  bool hdr = false;
  int audio_sample_rate = 0;
  int audio_channels = 0;
  std::int64_t audio_bitrate_bps = 0;
  Micros duration_us = 0;

  bool usable() const { return width > 0 && height > 0 && fps > 0.0; }
};

struct ExportRequest {
  QualityPreset preset = QualityPreset::kOriginal;
  int custom_height = 0;        // used when the user picks an explicit value
  double custom_fps = 0.0;      // 0 => keep source fps
  std::int64_t custom_bitrate_bps = 0;  // 0 => plan a bitrate automatically
  bool burn_in_picture = false; // subtitles/watermarks baked into the frame
  bool allow_upscale = false;
  bool prefer_hevc = false;
  bool hevc_supported = false;
  bool hardware_encoder = true;
  double quality = 0.75;        // 0..1, maps to bits-per-pixel budget
  bool keep_source_audio = true;
  int target_sample_rate = 0;   // 0 => keep source
};

enum class PlanWarning {
  kNone = 0,
  kUpscaleClamped,          // requested > source, clamped back to source
  kUpscaleRequested,        // upscaling allowed: pixels are interpolated
  kFpsChanged,              // frame rate rewritten, no true interpolation
  kHevcUnavailable,         // HEVC requested but unsupported -> H.264
  kBitrateLowerThanSource,  // would lose detail
  kHdrNotPreserved,         // HDR source exported through an SDR pipeline
  kAudioReencoded,
  kPassthroughNoPictureChange,
  kUnknownSourceBitrate,
};

struct ExportPlan {
  bool ok = false;
  std::string error_code;       // set when ok == false

  bool reencode = true;
  bool passthrough_video = false;
  bool passthrough_audio = true;

  int width = 0;
  int height = 0;
  double fps = 0.0;
  VideoCodec codec = VideoCodec::kH264;
  std::int64_t video_bitrate_bps = 0;
  std::int64_t audio_bitrate_bps = 0;
  int audio_sample_rate = 0;
  int keyframe_interval_frames = 0;
  bool hardware_encoder = true;
  bool hdr = false;

  std::int64_t estimated_bytes = 0;
  std::vector<PlanWarning> warnings;

  bool has(PlanWarning w) const;
};

const char* WarningCode(PlanWarning w);

// Rounds to an even number (encoders require even dimensions; odd values are a
// classic source of one-pixel green bars).
int MakeEven(int value);

// Bits-per-pixel-per-frame budget for the requested quality. Calibrated so that
// "Original Quality" on a 1080p30 source lands at 8-12 Mbps, matching what the
// hardware encoders of mid-range Android devices produce at their highest
// quality preset.
double BitsPerPixel(double quality);

ExportPlan PlanExport(const SourceInfo& source, const ExportRequest& request);

// Height of the preset (0 for kOriginal / invalid custom values).
int PresetHeight(QualityPreset preset);

}  // namespace sf
