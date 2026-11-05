// JNI surface of libsubflow_core.so.
//
// Only *pure* logic lives behind JNI; decoding and encoding stay in Media3 on
// the Kotlin side. That keeps the native layer testable and lets the exporter
// call it from a background thread without touching the UI thread.
//
// NOTE: arrays are passed as parallel arrays (starts/ends/texts) instead of
// Java objects so the boundary stays allocation-cheap on low-end devices.
#include <jni.h>

#include <string>
#include <vector>

#include "sf_quality.h"
#include "sf_silence.h"
#include "sf_subtitle.h"
#include "sf_time.h"

namespace {


jint ThrowIllegalArgument(JNIEnv* env, const char* message) {
  if (jclass clazz = env->FindClass("java/lang/IllegalArgumentException")) {
    env->ThrowNew(clazz, message);
  }
  return -1;
}

std::string ToStdString(JNIEnv* env, jstring value) {
  if (value == nullptr) return std::string();
  const char* chars = env->GetStringUTFChars(value, nullptr);
  if (chars == nullptr) return std::string();
  std::string out(chars);
  env->ReleaseStringUTFChars(value, chars);
  return out;
}

sf::Micros ReadLong(JNIEnv* env, jlongArray array, jsize index) {
  jlong value = 0;
  env->GetLongArrayRegion(array, index, 1, &value);
  return static_cast<sf::Micros>(value);
}

std::vector<sf::Segment> ReadSegments(JNIEnv* env, jlongArray starts, jlongArray ends,
                                      jobjectArray texts, jobjectArray styles) {
  std::vector<sf::Segment> segments;
  if (starts == nullptr || ends == nullptr || texts == nullptr) return segments;
  const jsize count = env->GetArrayLength(starts);
  if (env->GetArrayLength(ends) != count) return segments;
  if (env->GetArrayLength(texts) != count) return segments;
  segments.reserve(static_cast<std::size_t>(count));
  for (jsize i = 0; i < count; ++i) {
    sf::Segment segment;
    segment.start_us = ReadLong(env, starts, i);
    segment.end_us = ReadLong(env, ends, i);
    auto text = static_cast<jstring>(env->GetObjectArrayElement(texts, i));
    segment.text = ToStdString(env, text);
    env->DeleteLocalRef(text);
    if (styles != nullptr && env->GetArrayLength(styles) == count) {
      auto style = static_cast<jstring>(env->GetObjectArrayElement(styles, i));
      segment.style = ToStdString(env, style);
      env->DeleteLocalRef(style);
    }
    if (segment.end_us > segment.start_us && !segment.text.empty()) {
      segments.push_back(std::move(segment));
    }
  }
  return segments;
}

}  // namespace

extern "C" {

JNIEXPORT jstring JNICALL
Java_app_subflow_core_NativeCore_nativeWriteSrt(JNIEnv* env, jobject /*thiz*/,
                                               jlongArray starts, jlongArray ends,
                                               jobjectArray texts) {
  const std::vector<sf::Segment> segments = ReadSegments(env, starts, ends, texts, nullptr);
  if (env->ExceptionCheck()) return nullptr;
  const sf::SubtitleWriteResult result = sf::WriteSrt(segments);
  return env->NewStringUTF(result.content.c_str());
}

JNIEXPORT jstring JNICALL
Java_app_subflow_core_NativeCore_nativeWriteAss(
    JNIEnv* env, jobject /*thiz*/, jlongArray starts, jlongArray ends, jobjectArray texts,
    jobjectArray styles, jstring fontName, jdouble fontSize, jint primaryRgb,
    jint outlineRgb, jboolean bold, jdouble outlineWidth, jdouble shadowDepth,
    jint alignment, jint playResX, jint playResY) {
  const std::vector<sf::Segment> segments = ReadSegments(env, starts, ends, texts, styles);
  if (env->ExceptionCheck()) return nullptr;

  sf::AssStyle style;
  style.font_name = ToStdString(env, fontName);
  if (style.font_name.empty()) style.font_name = "Vazirmatn";
  style.font_size = static_cast<double>(fontSize);
  style.primary_color = static_cast<std::uint32_t>(primaryRgb) & 0xFFFFFFu;
  style.outline_color = static_cast<std::uint32_t>(outlineRgb) & 0xFFFFFFu;
  style.bold = bold == JNI_TRUE;
  style.outline_width = static_cast<double>(outlineWidth);
  style.shadow_depth = static_cast<double>(shadowDepth);
  style.alignment = static_cast<int>(alignment);

  const sf::SubtitleWriteResult result =
      sf::WriteAss(segments, style, static_cast<int>(playResX), static_cast<int>(playResY));
  return env->NewStringUTF(result.content.c_str());
}

// Returns a flattened [start0, end0, start1, end1, ...] array of removable
// silent ranges, in source microseconds.
JNIEXPORT jlongArray JNICALL
Java_app_subflow_core_NativeCore_nativeDetectSilence(JNIEnv* env, jobject /*thiz*/,
                                                     jfloatArray pcm, jint sampleRate,
                                                     jdouble thresholdDbfs,
                                                     jlong minSilenceUs, jlong minSpeechUs,
                                                     jlong padUs) {
  if (pcm == nullptr) {
    ThrowIllegalArgument(env, "pcm must not be null");
    return nullptr;
  }
  if (sampleRate <= 0) {
    ThrowIllegalArgument(env, "sampleRate must be > 0");
    return nullptr;
  }
  const jsize length = env->GetArrayLength(pcm);
  std::vector<jfloat> buffer(static_cast<std::size_t>(length));
  env->GetFloatArrayRegion(pcm, 0, length, buffer.data());
  if (env->ExceptionCheck()) return nullptr;

  // DetectSilence only reads float32 data; jfloat is IEEE-754 binary32 too.
  std::vector<float> samples(buffer.begin(), buffer.end());

  sf::SilenceConfig config;
  config.threshold_dbfs = static_cast<double>(thresholdDbfs);
  config.min_silence_us = static_cast<sf::Micros>(minSilenceUs);
  config.min_speech_us = static_cast<sf::Micros>(minSpeechUs);
  config.pad_us = static_cast<sf::Micros>(padUs);

  const sf::SilenceResult result =
      sf::DetectSilence(samples.data(), samples.size(), static_cast<int>(sampleRate), config);

  std::vector<jlong> flat;
  flat.reserve(result.silent.size() * 2);
  for (const sf::TimeRange& range : result.silent) {
    flat.push_back(static_cast<jlong>(range.start_us));
    flat.push_back(static_cast<jlong>(range.end_us));
  }
  jlongArray out = env->NewLongArray(static_cast<jsize>(flat.size()));
  if (out != nullptr && !flat.empty()) {
    env->SetLongArrayRegion(out, 0, static_cast<jsize>(flat.size()), flat.data());
  }
  return out;
}

// Compact JSON for the export screen. Built as a string because the payload is
// tiny and the Dart side only needs to display it.
JNIEXPORT jstring JNICALL
Java_app_subflow_core_NativeCore_nativePlanExport(
    JNIEnv* env, jobject /*thiz*/, jint srcWidth, jint srcHeight, jdouble srcFps,
    jlong srcBitrate, jboolean hdr, jint audioSampleRate, jint audioChannels,
    jlong audioBitrate, jlong durationUs, jint presetHeight, jdouble customFps,
    jlong customBitrate, jboolean burnIn, jboolean allowUpscale, jboolean preferHevc,
    jboolean hevcSupported, jboolean hardware, jboolean keepSourceAudio, jdouble quality) {
  sf::SourceInfo source;
  source.width = static_cast<int>(srcWidth);
  source.height = static_cast<int>(srcHeight);
  source.fps = static_cast<double>(srcFps);
  source.bitrate_bps = static_cast<std::int64_t>(srcBitrate);
  source.hdr = hdr == JNI_TRUE;
  source.audio_sample_rate = static_cast<int>(audioSampleRate);
  source.audio_channels = static_cast<int>(audioChannels);
  source.audio_bitrate_bps = static_cast<std::int64_t>(audioBitrate);
  source.duration_us = static_cast<sf::Micros>(durationUs);

  sf::ExportRequest request;
  switch (presetHeight) {
    case 480:
      request.preset = sf::QualityPreset::k480p;
      break;
    case 720:
      request.preset = sf::QualityPreset::k720p;
      break;
    case 1080:
      request.preset = sf::QualityPreset::k1080p;
      break;
    case 1440:
      request.preset = sf::QualityPreset::k1440p;
      break;
    case 2160:
      request.preset = sf::QualityPreset::k2160p;
      break;
    default:
      request.preset = sf::QualityPreset::kOriginal;
      break;
  }
  request.custom_fps = static_cast<double>(customFps);
  request.custom_bitrate_bps = static_cast<std::int64_t>(customBitrate);
  request.burn_in_picture = burnIn == JNI_TRUE;
  request.allow_upscale = allowUpscale == JNI_TRUE;
  request.prefer_hevc = preferHevc == JNI_TRUE;
  request.hevc_supported = hevcSupported == JNI_TRUE;
  request.hardware_encoder = hardware == JNI_TRUE;
  request.keep_source_audio = keepSourceAudio == JNI_TRUE;
  request.quality = static_cast<double>(quality);

  const sf::ExportPlan plan = sf::PlanExport(source, request);

  std::string json = "{";
  json += "\"ok\":" + std::string(plan.ok ? "true" : "false");
  json += ",\"errorCode\":\"" + plan.error_code + "\"";
  json += ",\"width\":" + std::to_string(plan.width);
  json += ",\"height\":" + std::to_string(plan.height);
  json += ",\"fps\":" + std::to_string(plan.fps);
  json += ",\"videoBitrate\":" + std::to_string(plan.video_bitrate_bps);
  json += ",\"audioBitrate\":" + std::to_string(plan.audio_bitrate_bps);
  json += ",\"audioSampleRate\":" + std::to_string(plan.audio_sample_rate);
  json += ",\"codec\":\"";
  json += plan.codec == sf::VideoCodec::kHevc ? "hevc" : "h264";
  json += "\"";
  json += ",\"reencode\":" + std::string(plan.reencode ? "true" : "false");
  json += ",\"passthroughVideo\":" + std::string(plan.passthrough_video ? "true" : "false");
  json += ",\"passthroughAudio\":" + std::string(plan.passthrough_audio ? "true" : "false");
  json += ",\"hardwareEncoder\":" + std::string(plan.hardware_encoder ? "true" : "false");
  json += ",\"hdr\":" + std::string(plan.hdr ? "true" : "false");
  json += ",\"keyframeInterval\":" + std::to_string(plan.keyframe_interval_frames);
  json += ",\"estimatedBytes\":" + std::to_string(plan.estimated_bytes);
  json += ",\"warnings\":[";
  for (std::size_t i = 0; i < plan.warnings.size(); ++i) {
    if (i > 0) json += ",";
    json += "\"";
    json += sf::WarningCode(plan.warnings[i]);
    json += "\"";
  }
  json += "]}";
  return env->NewStringUTF(json.c_str());
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* /*vm*/, void* /*reserved*/) {
  return JNI_VERSION_1_6;
}

}  // extern "C"
