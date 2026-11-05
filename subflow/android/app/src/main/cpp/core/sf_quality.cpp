#include "sf_quality.h"

#include <algorithm>
#include <cmath>
#include <cstdio>

namespace sf {
namespace {

constexpr std::int64_t kMaxH264BitrateBps = 60'000'000;   // Level 5.1 practical ceiling
constexpr std::int64_t kMaxHevcBitrateBps = 120'000'000;
constexpr std::int64_t kMinBitrateBps = 400'000;

int ScaledWidth(int source_w, int source_h, int target_h) {
  if (source_h <= 0) return source_w;
  return static_cast<int>(std::lround(static_cast<double>(source_w) * target_h / source_h));
}

bool SameDouble(double a, double b) { return std::fabs(a - b) < 0.01; }

}  // namespace

bool ExportPlan::has(PlanWarning w) const {
  return std::find(warnings.begin(), warnings.end(), w) != warnings.end();
}

const char* WarningCode(PlanWarning w) {
  switch (w) {
    case PlanWarning::kUpscaleClamped:
      return "UPSCALE_CLAMPED";
    case PlanWarning::kUpscaleRequested:
      return "UPSCALE_INTERPOLATED";
    case PlanWarning::kFpsChanged:
      return "FPS_CHANGED";
    case PlanWarning::kHevcUnavailable:
      return "HEVC_UNAVAILABLE_H264";
    case PlanWarning::kBitrateLowerThanSource:
      return "BITRATE_BELOW_SOURCE";
    case PlanWarning::kHdrNotPreserved:
      return "HDR_NOT_PRESERVED";
    case PlanWarning::kAudioReencoded:
      return "AUDIO_REENCODED";
    case PlanWarning::kPassthroughNoPictureChange:
      return "STREAM_COPY";
    case PlanWarning::kUnknownSourceBitrate:
      return "UNKNOWN_SOURCE_BITRATE";
    case PlanWarning::kNone:
    default:
      return "NONE";
  }
}

int MakeEven(int value) {
  if (value <= 1) return 2;
  return value - (value % 2);
}

double BitsPerPixel(double quality) {
  const double q = std::min(1.0, std::max(0.0, quality));
  // 0.05 bpp is visibly soft, 0.16 bpp is transparent for H.264 High profile.
  return 0.05 + q * 0.11;
}

int PresetHeight(QualityPreset preset) {
  switch (preset) {
    case QualityPreset::kOriginal:
      return 0;
    default:
      return static_cast<int>(preset);
  }
}

ExportPlan PlanExport(const SourceInfo& source, const ExportRequest& request) {
  ExportPlan plan;
  if (!source.usable()) {
    plan.ok = false;
    plan.error_code = "SOURCE_UNUSABLE";
    return plan;
  }

  const int requested_height =
      request.custom_height > 0 ? request.custom_height : PresetHeight(request.preset);
  // Portrait sources: the preset names a *short edge* class, so a 1080x1920
  // video must not be treated as "already 1080p tall" and upscaled to 2160.
  const int source_short_edge = std::min(source.width, source.height);
  const bool portrait = source.height > source.width;

  int target_short_edge = 0;
  if (requested_height > 0) {
    target_short_edge = requested_height;
  } else {
    target_short_edge = source_short_edge;  // Original
  }

  const bool upscale = target_short_edge > source_short_edge;
  if (upscale && !request.allow_upscale) {
    target_short_edge = source_short_edge;
    plan.warnings.push_back(PlanWarning::kUpscaleClamped);
  } else if (upscale) {
    plan.warnings.push_back(PlanWarning::kUpscaleRequested);
  }

  // Geometry: preserve aspect exactly, scale the short edge, keep both even.
  if (target_short_edge == source_short_edge) {
    plan.width = MakeEven(source.width);
    plan.height = MakeEven(source.height);
  } else if (portrait) {
    plan.width = MakeEven(target_short_edge);
    plan.height = MakeEven(ScaledWidth(source.height, source.width, target_short_edge));
  } else {
    plan.height = MakeEven(target_short_edge);
    plan.width = MakeEven(ScaledWidth(source.width, source.height, target_short_edge));
  }

  // Frame rate: keep the source unless the user asked for something else.
  plan.fps = source.fps;
  if (request.custom_fps > 0.0 && !SameDouble(request.custom_fps, source.fps)) {
    plan.fps = request.custom_fps;
    plan.warnings.push_back(PlanWarning::kFpsChanged);
  }

  // Codec.
  plan.codec = VideoCodec::kH264;
  if (request.prefer_hevc) {
    if (request.hevc_supported) {
      plan.codec = VideoCodec::kHevc;
    } else {
      plan.warnings.push_back(PlanWarning::kHevcUnavailable);
    }
  }
  plan.hardware_encoder = request.hardware_encoder;

  // Does the picture have to be decoded and re-encoded at all?
  const bool geometry_changed = plan.width != MakeEven(source.width) ||
                                plan.height != MakeEven(source.height) ||
                                !SameDouble(plan.fps, source.fps);
  plan.reencode = request.burn_in_picture || geometry_changed ||
                  (request.prefer_hevc && plan.codec != source.codec);
  plan.passthrough_video = !plan.reencode;
  plan.passthrough_audio = request.keep_source_audio && target_short_edge == source_short_edge &&
                           request.target_sample_rate == 0;
  if (plan.passthrough_video) {
    plan.warnings.push_back(PlanWarning::kPassthroughNoPictureChange);
  }

  // Bitrate budget from *pixels per second*, not from the preset name.
  const double pixels = static_cast<double>(plan.width) * static_cast<double>(plan.height);
  const double bpp = BitsPerPixel(request.quality);
  const double codec_factor = plan.codec == VideoCodec::kHevc ? 0.62 : 1.0;
  std::int64_t planned =
      static_cast<std::int64_t>(pixels * plan.fps * bpp * codec_factor / 1000.0) * 1000;

  if (request.custom_bitrate_bps > 0) {
    planned = request.custom_bitrate_bps;
  } else if (plan.passthrough_video && source.bitrate_bps > 0) {
    planned = source.bitrate_bps;
  } else if (source.bitrate_bps > 0) {
    // Never plan below the source's own density: that is exactly the silent
    // quality loss the product forbids. Scale the source bitrate by the pixel
    // ratio so downscales may use less, but keep a 0.85 headroom factor.
    const double src_pixels = static_cast<double>(source.width) * source.height;
    const double ratio = src_pixels > 0 ? pixels / src_pixels : 1.0;
    const std::int64_t scaled_source =
        static_cast<std::int64_t>(static_cast<double>(source.bitrate_bps) * ratio * 0.85);
    planned = std::max(planned, scaled_source);
    if (planned < source.bitrate_bps && ratio >= 0.999) {
      plan.warnings.push_back(PlanWarning::kBitrateLowerThanSource);
    }
  } else {
    plan.warnings.push_back(PlanWarning::kUnknownSourceBitrate);
  }

  const std::int64_t ceiling =
      plan.codec == VideoCodec::kHevc ? kMaxHevcBitrateBps : kMaxH264BitrateBps;
  plan.video_bitrate_bps = std::min(ceiling, std::max(kMinBitrateBps, planned));

  // Audio: copy when possible, otherwise re-encode at a sane default.
  plan.audio_sample_rate =
      request.target_sample_rate > 0 ? request.target_sample_rate : source.audio_sample_rate;
  if (source.audio_sample_rate == 0) {
    plan.passthrough_audio = false;
  }
  const std::int64_t audio_default =
      source.audio_channels > 2 ? 192'000 : (source.audio_channels == 1 ? 96'000 : 128'000);
  plan.audio_bitrate_bps =
      source.audio_bitrate_bps > 0 ? source.audio_bitrate_bps : audio_default;
  if (!plan.passthrough_audio) {
    plan.warnings.push_back(PlanWarning::kAudioReencoded);
  }

  // HDR passthrough is only honest when nothing touches the picture and the
  // encoder is known to keep the transfer function.
  if (source.hdr) {
    plan.hdr = plan.passthrough_video;
    if (!plan.hdr) plan.warnings.push_back(PlanWarning::kHdrNotPreserved);
  }

  plan.keyframe_interval_frames = std::max(1, static_cast<int>(std::lround(plan.fps * 2.0)));
  if (source.duration_us > 0) {
    const double seconds = static_cast<double>(source.duration_us) / 1000000.0;
    const double bits = (static_cast<double>(plan.video_bitrate_bps) +
                         static_cast<double>(plan.audio_bitrate_bps)) *
                        seconds;
    plan.estimated_bytes = static_cast<std::int64_t>(bits / 8.0);
  }

  plan.ok = true;
  return plan;
}

}  // namespace sf
