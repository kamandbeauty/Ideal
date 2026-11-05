#pragma once

#include <cstddef>
#include <string>
#include <vector>

#include "sf_common.h"

namespace sf {

/// One recognized caption. Times are timeline microseconds, the same unit the
/// editor, the DAO and the exporters use, so a transcript needs no conversion
/// before it becomes a subtitle document.
struct AsrSegment {
  Micros start_us = 0;
  Micros end_us = 0;
  std::string text;
};

struct AsrOptions {
  /// Worker threads for the encoder/decoder. Device-dependent, clamped by the
  /// implementation (2..8); more threads than big cores is slower, not faster.
  int threads = 4;

  /// Whisper language code: "fa", "en", "auto" (auto-detect).
  std::string language = "auto";

  /// Translate to English instead of transcribing. Off: we never rewrite the
  /// user's words.
  bool translate = false;

  /// Segments longer than this are split on word boundaries so the editor has
  /// captions it can actually retime.
  Micros max_segment_us = 7 * 1000 * 1000;
};

/// True when this binary was compiled against whisper.cpp. The Kotlin layer
/// reports it to Dart, and the UI refuses to offer transcription on an APK that
/// was built without the engine instead of failing halfway through.
bool AsrAvailable();

/// Offline speech recognition over mono 16 kHz float PCM.
///
/// One engine instance owns one loaded model (`ggml-*.bin`). It is *not*
/// thread-safe: the JNI layer serializes calls, which is also what the UI wants
/// (one transcription at a time, cancelling the previous one first).
class AsrEngine {
 public:
  AsrEngine();
  ~AsrEngine();

  AsrEngine(const AsrEngine&) = delete;
  AsrEngine& operator=(const AsrEngine&) = delete;

  /// Loads a ggml model file. Returns false and fills `error` on any failure;
  /// a failed load never leaves the engine half-initialised.
  bool Load(const std::string& model_path, std::string* error);

  void Unload();

  bool Ready() const;

  /// Transcribes `pcm` (mono, 16 kHz, samples in [-1, 1]).
  ///
  /// Segments are appended to `out` in timeline order, with empty and
  /// zero-length results dropped. `error` is filled for a refused or aborted
  /// run. Progress is exposed through Progress() while this runs.
  bool Transcribe(const float* pcm, std::size_t samples, const AsrOptions& options,
                  std::vector<AsrSegment>* out, std::string* error);

  /// Asks a running Transcribe() to stop. Safe to call from another thread.
  void Cancel();

  /// 0..100 while a transcription runs, 0 when idle.
  int Progress() const;

 private:
  struct Impl;
  Impl* impl_ = nullptr;
};

}  // namespace sf
