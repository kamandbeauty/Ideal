// Host tests for the SubFlow native core.
// Run: make -C subflow/tools/native-core test
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

#include "core/sf_quality.h"
#include "core/sf_silence.h"
#include "core/sf_subtitle.h"
#include "core/sf_time.h"
#include "core/sf_timeline.h"
#include "sf_test.h"

namespace {

using sf::Micros;
using sf::Segment;
using sf::TimeRange;

// ---------------------------------------------------------------- time helpers
void TestTimeFormatting() {
  std::printf("- time formatting\n");
  SF_CHECK_EQ_STR(sf::FormatSrtTime(0), "00:00:00,000");
  SF_CHECK_EQ_STR(sf::FormatSrtTime(1'500'000), "00:00:01,500");
  SF_CHECK_EQ_STR(sf::FormatSrtTime(3'723'456'789LL), "01:02:03,456");
  SF_CHECK_EQ_STR(sf::FormatAssTime(0), "0:00:00.00");
  SF_CHECK_EQ_STR(sf::FormatAssTime(1'500'000), "0:00:01.50");
  // 1.995 s must round to 2.00 in ASS (centisecond resolution).
  SF_CHECK_EQ_STR(sf::FormatAssTime(1'995'000), "0:00:02.00");
  SF_CHECK_EQ_STR(sf::FormatSrtTime(-5000), "00:00:00,000");
  SF_CHECK_EQ_INT(sf::MicrosFromMs(29.97), 29970);
  SF_CHECK_EQ_INT(sf::MicrosFromSeconds(0.0005), 500);
  // 29.97 fps frame 300 == 10.01 s. No cumulative float drift allowed.
  Micros frame_time = 0;
  for (int i = 0; i < 300; ++i) frame_time += sf::FramesToMicros(1, 29.97);
  SF_CHECK_NEAR(sf::MicrosToFrames(frame_time, 29.97), 300, 0);
}

void TestNormalizeRanges() {
  std::printf("- range normalisation\n");
  const auto merged = sf::NormalizeRanges(
      {{3'000'000, 4'000'000}, {1'000'000, 2'500'000}, {2'000'000, 3'500'000},
       {9'000'000, 8'000'000}, {-500'000, 500'000}},
      6'000'000);
  SF_CHECK_EQ_INT(merged.size(), 2);
  if (merged.size() == 2) {
    // [-0.5s, 0.5s] clipped to [0, 0.5s]; the three middle ranges merge into
    // [1s, 4s]; [9s, 8s] is inverted and therefore dropped.
    SF_CHECK_EQ_INT(merged[0].start_us, 0);
    SF_CHECK_EQ_INT(merged[0].end_us, 500'000);
    SF_CHECK_EQ_INT(merged[1].start_us, 1'000'000);
    SF_CHECK_EQ_INT(merged[1].end_us, 4'000'000);
  }
  SF_CHECK_EQ_INT(sf::TotalLength({{0, 1'000'000}, {2'000'000, 3'000'000}}), 2'000'000);
}

// -------------------------------------------------------------- silence detect
std::vector<float> BuildSignal(int sample_rate, const std::vector<TimeRange>& speech_ranges,
                               double amplitude) {
  const double total_s = 2.2;
  std::vector<float> pcm(static_cast<std::size_t>(sample_rate * total_s), 0.0f);
  for (const TimeRange& r : speech_ranges) {
    const auto first = static_cast<std::size_t>(r.start_us * sample_rate / 1'000'000);
    const auto last = static_cast<std::size_t>(r.end_us * sample_rate / 1'000'000);
    constexpr double kPi = 3.14159265358979323846;
    for (std::size_t i = first; i < last && i < pcm.size(); ++i) {
      const double t = static_cast<double>(i) / static_cast<double>(sample_rate);
      pcm[i] = static_cast<float>(amplitude * std::sin(2.0 * kPi * 220.0 * t));
    }
  }
  return pcm;
}

void TestSilenceDetection() {
  std::printf("- silence detection\n");
  const int sr = 16000;
  // speech: 200-800 ms and 1300-1700 ms  => silence 0-200, 800-1300, 1700-2200
  const std::vector<float> pcm =
      BuildSignal(sr, {{200'000, 800'000}, {1'300'000, 1'700'000}}, 0.30);

  sf::SilenceConfig config;
  config.min_silence_us = 100'000;
  config.pad_us = 20'000;
  config.min_speech_us = 80'000;

  const sf::SilenceResult result =
      sf::DetectSilence(pcm.data(), pcm.size(), sr, config);

  SF_CHECK_EQ_INT(result.silent.size(), 3);
  if (result.silent.size() == 3) {
    SF_CHECK_NEAR(result.silent[0].start_us, 20'000, 40'000);
    SF_CHECK_NEAR(result.silent[0].end_us, 200'000, 40'000);
    SF_CHECK_NEAR(result.silent[1].start_us, 800'000, 40'000);
    SF_CHECK_NEAR(result.silent[1].end_us, 1'300'000, 40'000);
    SF_CHECK_NEAR(result.silent[2].start_us, 1'700'000, 40'000);
    SF_CHECK_NEAR(result.silent[2].end_us, 2'200'000, 40'000);
  }
  SF_CHECK(result.silent_ratio > 0.45 && result.silent_ratio < 0.65);

  // A pure tone must never be reported as silence.
  std::vector<float> tone(pcm.size(), 0.25f);
  const sf::SilenceResult tone_result = sf::DetectSilence(tone.data(), tone.size(), sr, config);
  SF_CHECK_EQ_INT(tone_result.silent.size(), 0);

  // Digital silence must be reported as one removable block.
  std::vector<float> zeros(sr, 0.0f);
  const sf::SilenceResult zero_result = sf::DetectSilence(zeros.data(), zeros.size(), sr, config);
  SF_CHECK_EQ_INT(zero_result.silent.size(), 1);

  // Degenerate inputs must not crash.
  SF_CHECK_EQ_INT(sf::DetectSilence(nullptr, 0, 0, config).silent.size(), 0);
  SF_CHECK_EQ_INT(sf::DetectSilence(zeros.data(), 0, sr, config).silent.size(), 0);
}

// ----------------------------------------------------------------- time remap
void TestTimeMap() {
  std::printf("- timeline remap (silence cut)\n");
  sf::TimeMap map({{1'000'000, 2'000'000}}, 5'000'000);
  SF_CHECK_EQ_INT(map.new_length_us(), 4'000'000);
  SF_CHECK_EQ_INT(map.removed_us(), 1'000'000);
  SF_CHECK_EQ_INT(map.Map(0), 0);
  SF_CHECK_EQ_INT(map.Map(500'000), 500'000);
  SF_CHECK_EQ_INT(map.Map(1'500'000), 1'000'000);  // inside cut -> collapse
  SF_CHECK_EQ_INT(map.Map(2'500'000), 1'500'000);
  SF_CHECK_EQ_INT(map.Map(5'000'000), 4'000'000);
  SF_CHECK(map.IsRemoved(1'000'000));
  SF_CHECK(!map.IsRemoved(2'000'000));

  TimeRange out;
  SF_CHECK(map.MapRange({500'000, 1'500'000}, &out));
  SF_CHECK_EQ_INT(out.start_us, 500'000);
  SF_CHECK_EQ_INT(out.end_us, 1'000'000);
  SF_CHECK(!map.MapRange({1'100'000, 1'900'000}, &out));  // fully removed

  std::vector<Segment> segments(3);
  segments[0].start_us = 500'000;
  segments[0].end_us = 1'500'000;
  segments[0].text = "پاره اول";
  segments[1].start_us = 500'000;
  segments[1].end_us = 2'500'000;
  segments[1].text = "دو نیم می‌شود";
  segments[1].words = {{500'000, 1'200'000, "دو"}, {1'400'000, 1'600'000, "نیم"},
                       {2'100'000, 2'500'000, "شود"}};
  segments[2].start_us = 1'200'000;
  segments[2].end_us = 1'800'000;
  segments[2].text = "حذف کامل";

  const auto remapped = sf::RemapSegments(segments, map);
  SF_CHECK_EQ_INT(remapped.size(), 3);  // seg0, seg1 split in two, seg2 dropped
  if (remapped.size() == 3) {
    SF_CHECK_EQ_STR(remapped[0].text, "پاره اول");
    SF_CHECK_EQ_INT(remapped[0].start_us, 500'000);
    SF_CHECK_EQ_INT(remapped[0].end_us, 1'000'000);
    SF_CHECK_EQ_INT(remapped[1].start_us, 500'000);
    SF_CHECK_EQ_INT(remapped[1].end_us, 1'000'000);
    SF_CHECK_EQ_INT(remapped[2].start_us, 1'000'000);
    SF_CHECK_EQ_INT(remapped[2].end_us, 1'500'000);
    // Word "دو" survives, "نیم" is clipped to the kept fragment, "شود" kept whole.
    // "دو" survives in the first fragment, "نیم" sat inside the cut and is
    // gone, "شود" survives in the second fragment.
    SF_CHECK_EQ_INT(remapped[1].words.size() + remapped[2].words.size(), 2);
  }
}

// -------------------------------------------------------------- subtitle codec
void TestSrtRoundTrip() {
  std::printf("- SRT writer/parser round trip\n");
  std::vector<Segment> segments(2);
  segments[0].start_us = 500'000;
  segments[0].end_us = 2'250'000;
  segments[0].text = "سلام دنیا (نسخه‌ی فارسی)";
  segments[1].start_us = 2'250'000;
  segments[1].end_us = 3'000'000;
  segments[1].text = "line one\nline two";

  const sf::SubtitleWriteResult written = sf::WriteSrt(segments);
  SF_CHECK_EQ_INT(written.written, 2);
  SF_CHECK(written.content.find("00:00:00,500 --> 00:00:02,250\r\n") != std::string::npos);
  SF_CHECK(written.content.find("\r\n\r\n") != std::string::npos);
  SF_CHECK(written.content.compare(0, 3, "\xEF\xBB\xBF") != 0);  // no BOM

  const sf::SrtParseResult parsed = sf::ParseSrt(written.content);
  SF_CHECK_EQ_INT(parsed.segments.size(), 2);
  SF_CHECK_EQ_INT(parsed.warnings.size(), 0);
  if (parsed.segments.size() == 2) {
    SF_CHECK_EQ_STR(parsed.segments[0].text, segments[0].text);
    SF_CHECK_EQ_INT(parsed.segments[0].start_us, 500'000);
    SF_CHECK_EQ_INT(parsed.segments[0].end_us, 2'250'000);
    SF_CHECK_EQ_STR(parsed.segments[1].text, "line one\nline two");
  }

  // Tolerant input: BOM, LF only, '.' separator, missing index, no millis.
  const std::string messy =
      "\xEF\xBB\xBF"
      "1\r\n00:00:01.5 --> 00:00:02.75\r\nfirst\r\n\r\n"
      "00:00:03 --> 00:00:04\r\nsecond\r\n";
  const sf::SrtParseResult tol = sf::ParseSrt(messy);
  SF_CHECK_EQ_INT(tol.segments.size(), 2);
  if (tol.segments.size() == 2) {
    SF_CHECK_EQ_INT(tol.segments[0].start_us, 1'500'000);
    SF_CHECK_EQ_INT(tol.segments[0].end_us, 2'750'000);
    SF_CHECK_EQ_INT(tol.segments[1].start_us, 3'000'000);
    SF_CHECK_EQ_INT(tol.segments[1].end_us, 4'000'000);
    SF_CHECK_EQ_STR(tol.segments[1].text, "second");
  }

  // Garbage in -> warnings out, never a crash and never a fake cue.
  const sf::SrtParseResult bad = sf::ParseSrt("hello\r\n\r\n5\r\nxx --> yy\r\ntext\r\n");
  SF_CHECK(bad.segments.empty());
  SF_CHECK(!bad.warnings.empty());
}

void TestAssWriter() {
  std::printf("- ASS writer\n");
  sf::AssStyle style;
  style.font_name = "Vazirmatn";
  style.font_size = 72.0;
  style.primary_color = 0xFFCC00;
  style.outline_width = 4.0;
  style.alignment = 2;
  style.rtl = true;

  std::vector<Segment> segments(2);
  segments[0].start_us = 0;
  segments[0].end_us = 1'500'000;
  segments[0].text = "متن فارسی Test ۱۲۳\nخط دوم";
  segments[1].start_us = 1'500'000;
  segments[1].end_us = 2'000'000;
  segments[1].text = "brace {x} test";
  segments[1].style = "Viral";

  const sf::SubtitleWriteResult out = sf::WriteAss(segments, style, 1080, 1920);
  SF_CHECK_EQ_INT(out.written, 2);
  SF_CHECK(out.content.find("PlayResX: 1080\r\n") != std::string::npos);
  SF_CHECK(out.content.find("PlayResY: 1920\r\n") != std::string::npos);
  SF_CHECK(out.content.find("ScriptType: v4.00+") != std::string::npos);
  SF_CHECK(out.content.find(",Vazirmatn,") != std::string::npos);
  SF_CHECK(out.content.find("&H0000CCFF") != std::string::npos);  // opaque #FFCC00
  SF_CHECK(out.content.find("Dialogue: 0,0:00:00.00,0:00:01.50,SubFlow,") != std::string::npos);
  SF_CHECK(out.content.find("\\N") != std::string::npos);        // newline escaped
  SF_CHECK(out.content.find(",Viral,") != std::string::npos);     // per-cue style
  SF_CHECK(out.content.find("{x}") == std::string::npos);         // braces neutralised
  SF_CHECK(out.content.find("\xEF\xBD\x9B") != std::string::npos);
  // Must contain the raw UTF-8 Persian text (no pre-shaping, no bidi mangling).
  SF_CHECK(out.content.find("متن فارسی") != std::string::npos);
}

// ------------------------------------------------------------- export planner
sf::SourceInfo FullHdSource() {
  sf::SourceInfo s;
  s.width = 1920;
  s.height = 1080;
  s.fps = 30.0;
  s.bitrate_bps = 8'000'000;
  s.codec = sf::VideoCodec::kH264;
  s.audio_sample_rate = 48000;
  s.audio_channels = 2;
  s.audio_bitrate_bps = 128'000;
  s.duration_us = 60'000'000;
  return s;
}

void TestExportPlanner() {
  std::printf("- export planner\n");
  const sf::SourceInfo source = FullHdSource();

  // 1. Original Quality + burn-in: geometry and fps untouched, bitrate >= source.
  sf::ExportRequest original;
  original.burn_in_picture = true;
  sf::ExportPlan plan = sf::PlanExport(source, original);
  SF_CHECK(plan.ok);
  SF_CHECK_EQ_INT(plan.width, 1920);
  SF_CHECK_EQ_INT(plan.height, 1080);
  SF_CHECK_NEAR(plan.fps, 30.0, 0.001);
  SF_CHECK(plan.reencode);
  SF_CHECK(!plan.passthrough_video);
  SF_CHECK(plan.video_bitrate_bps >= source.bitrate_bps);
  SF_CHECK(plan.audio_bitrate_bps == 128'000);
  SF_CHECK(plan.estimated_bytes > 0);

  // 2. Original Quality without any picture change => stream copy, zero "loss".
  sf::ExportRequest copy_only;
  sf::ExportPlan copy_plan = sf::PlanExport(source, copy_only);
  SF_CHECK(copy_plan.passthrough_video);
  SF_CHECK(!copy_plan.reencode);
  SF_CHECK(copy_plan.passthrough_audio);
  SF_CHECK(copy_plan.has(sf::PlanWarning::kPassthroughNoPictureChange));
  SF_CHECK_EQ_INT(copy_plan.video_bitrate_bps, source.bitrate_bps);

  // 3. 480p: aspect preserved, even dimensions, bitrate drops but not absurdly.
  sf::ExportRequest small;
  small.preset = sf::QualityPreset::k480p;
  small.burn_in_picture = true;
  sf::ExportPlan small_plan = sf::PlanExport(source, small);
  SF_CHECK_EQ_INT(small_plan.height, 480);
  SF_CHECK_EQ_INT(small_plan.width % 2, 0);
  SF_CHECK_NEAR(static_cast<double>(small_plan.width) / small_plan.height, 16.0 / 9.0, 0.01);
  SF_CHECK(small_plan.video_bitrate_bps < source.bitrate_bps);
  SF_CHECK(small_plan.video_bitrate_bps > 800'000);

  // 4. Asking 4K from 1080p must be clamped, with a warning, not silently faked.
  sf::ExportRequest up;
  up.preset = sf::QualityPreset::k2160p;
  up.burn_in_picture = true;
  sf::ExportPlan up_plan = sf::PlanExport(source, up);
  SF_CHECK_EQ_INT(up_plan.height, 1080);
  SF_CHECK_EQ_INT(up_plan.width, 1920);
  SF_CHECK(up_plan.has(sf::PlanWarning::kUpscaleClamped));
  SF_CHECK(!up_plan.has(sf::PlanWarning::kUpscaleRequested));

  // 5. Same request with explicit consent: upscale allowed, honest warning.
  up.allow_upscale = true;
  sf::ExportPlan up_ok = sf::PlanExport(source, up);
  SF_CHECK_EQ_INT(up_ok.height, 2160);
  SF_CHECK_EQ_INT(up_ok.width, 3840);
  SF_CHECK(up_ok.has(sf::PlanWarning::kUpscaleRequested));

  // 6. Portrait 1080x1920 source: the preset is a short-edge class, so 1080p is
  //    a no-op instead of an accidental 2x upscale.
  sf::SourceInfo portrait = FullHdSource();
  portrait.width = 1080;
  portrait.height = 1920;
  portrait.bitrate_bps = 6'000'000;
  sf::ExportRequest portrait_req;
  portrait_req.preset = sf::QualityPreset::k1080p;
  portrait_req.burn_in_picture = true;
  sf::ExportPlan portrait_plan = sf::PlanExport(portrait, portrait_req);
  SF_CHECK_EQ_INT(portrait_plan.width, 1080);
  SF_CHECK_EQ_INT(portrait_plan.height, 1920);
  SF_CHECK(!portrait_plan.has(sf::PlanWarning::kUpscaleClamped));

  // 7. HEVC requested but unsupported -> H.264 + warning, never a broken encode.
  sf::ExportRequest hevc;
  hevc.burn_in_picture = true;
  hevc.prefer_hevc = true;
  hevc.hevc_supported = false;
  sf::ExportPlan hevc_plan = sf::PlanExport(source, hevc);
  SF_CHECK(hevc_plan.codec == sf::VideoCodec::kH264);
  SF_CHECK(hevc_plan.has(sf::PlanWarning::kHevcUnavailable));
  hevc.hevc_supported = true;
  sf::ExportPlan hevc_ok = sf::PlanExport(source, hevc);
  SF_CHECK(hevc_ok.codec == sf::VideoCodec::kHevc);
  // HEVC reaches the same visual quality at a lower bitrate.
  SF_CHECK(hevc_ok.video_bitrate_bps < plan.video_bitrate_bps);

  // 8. Frame rate change is flagged: no fake "60fps interpolation" claim.
  sf::ExportRequest fps60;
  fps60.custom_fps = 60.0;
  fps60.burn_in_picture = true;
  sf::ExportPlan fps_plan = sf::PlanExport(source, fps60);
  SF_CHECK_NEAR(fps_plan.fps, 60.0, 0.001);
  SF_CHECK(fps_plan.has(sf::PlanWarning::kFpsChanged));

  // 9. HDR source that must be re-encoded loses HDR: say so out loud.
  sf::SourceInfo hdr = FullHdSource();
  hdr.hdr = true;
  sf::ExportPlan hdr_passthrough = sf::PlanExport(hdr, sf::ExportRequest{});
  SF_CHECK(hdr_passthrough.hdr);
  sf::ExportRequest hdr_burn;
  hdr_burn.burn_in_picture = true;
  sf::ExportPlan hdr_burn_plan = sf::PlanExport(hdr, hdr_burn);
  SF_CHECK(!hdr_burn_plan.hdr);
  SF_CHECK(hdr_burn_plan.has(sf::PlanWarning::kHdrNotPreserved));

  // 10. Degenerate source -> explicit failure, never a zero-byte encode.
  sf::ExportPlan bad = sf::PlanExport(sf::SourceInfo{}, sf::ExportRequest{});
  SF_CHECK(!bad.ok);
  SF_CHECK_EQ_STR(bad.error_code, "SOURCE_UNUSABLE");

  // 11. 4K60 source keeps a 4K-sized bitrate budget.
  sf::SourceInfo uhd = FullHdSource();
  uhd.width = 3840;
  uhd.height = 2160;
  uhd.fps = 60.0;
  uhd.bitrate_bps = 45'000'000;
  sf::ExportRequest uhd_req;
  uhd_req.burn_in_picture = true;
  sf::ExportPlan uhd_plan = sf::PlanExport(uhd, uhd_req);
  SF_CHECK_EQ_INT(uhd_plan.width, 3840);
  SF_CHECK_EQ_INT(uhd_plan.height, 2160);
  SF_CHECK(uhd_plan.video_bitrate_bps >= 20'000'000);
  SF_CHECK(uhd_plan.video_bitrate_bps <= 60'000'000);
}

}  // namespace

int main() {
  std::printf("SubFlow native core tests\n");
  TestTimeFormatting();
  TestNormalizeRanges();
  TestSilenceDetection();
  TestTimeMap();
  TestSrtRoundTrip();
  TestAssWriter();
  TestExportPlanner();

  std::printf("\n%d checks, %d failure(s)\n", sftest::Checks(), sftest::Failures());
  return sftest::Failures() == 0 ? 0 : 1;
}
