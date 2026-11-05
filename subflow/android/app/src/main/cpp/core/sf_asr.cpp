#include "sf_asr.h"

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <limits>
#include <mutex>
#include <sstream>

#if defined(SF_HAVE_WHISPER)
#include "whisper.h"
#endif

namespace sf {
namespace {

#if defined(SF_HAVE_WHISPER)
constexpr int kSampleRate = 16000;
constexpr std::size_t kMinSamples = kSampleRate / 2;  // 500 ms of audio

std::string Trim(const std::string& value) {
  std::size_t first = 0;
  while (first < value.size() &&
         (value[first] == ' ' || value[first] == '\n' || value[first] == '\r' ||
          value[first] == '\t')) {
    ++first;
  }
  std::size_t last = value.size();
  while (last > first) {
    const char c = value[last - 1];
    if (c != ' ' && c != '\n' && c != '\r' && c != '\t') break;
    --last;
  }
  return value.substr(first, last - first);
}

/// Splits an over-long caption at the last whitespace before the limit, so the
/// editor never gets a 30-second block it cannot retime without reflowing.
void AppendTimed(std::vector<AsrSegment>* out, Micros start_us, Micros end_us,
                 const std::string& text, Micros max_segment_us) {
  const std::string trimmed = Trim(text);
  if (trimmed.empty() || end_us <= start_us) return;
  if (max_segment_us <= 0 || end_us - start_us <= max_segment_us) {
    out->push_back(AsrSegment{start_us, end_us, trimmed});
    return;
  }

  std::vector<std::string> words;
  std::istringstream stream(trimmed);
  std::string word;
  while (stream >> word) words.push_back(word);
  if (words.empty()) return;

  const int parts = static_cast<int>((end_us - start_us + max_segment_us - 1) / max_segment_us);
  const int total_chars = [&words]() {
    int sum = 0;
    for (const std::string& w : words) sum += static_cast<int>(w.size());
    return sum;
  }();
  if (total_chars <= 0) return;

  const Micros span = end_us - start_us;
  std::size_t cursor = 0;
  int consumed_chars = 0;
  for (int part = 0; part < parts && cursor < words.size(); ++part) {
    const int target = total_chars * (part + 1) / parts;
    std::size_t stop = cursor;
    while (stop < words.size() && consumed_chars < target) {
      consumed_chars += static_cast<int>(words[stop].size());
      ++stop;
    }
    if (part == parts - 1) stop = words.size();
    if (stop <= cursor) stop = std::min(words.size(), cursor + 1);

    std::string chunk;
    for (std::size_t i = cursor; i < stop; ++i) {
      if (!chunk.empty()) chunk += ' ';
      chunk += words[i];
    }
    const Micros part_start = start_us + span * part / parts;
    const Micros part_end = start_us + span * (part + 1) / parts;
    if (!chunk.empty()) out->push_back(AsrSegment{part_start, part_end, chunk});
    cursor = stop;
  }
}
#endif  // SF_HAVE_WHISPER

}  // namespace

bool AsrAvailable() {
#if defined(SF_HAVE_WHISPER)
  return true;
#else
  return false;
#endif
}

struct AsrEngine::Impl {
#if defined(SF_HAVE_WHISPER)
  whisper_context* ctx = nullptr;
#endif
  std::atomic<bool> cancel{false};
  std::atomic<int> progress{0};
  std::mutex mutex;
};

AsrEngine::AsrEngine() : impl_(new Impl()) {}

AsrEngine::~AsrEngine() {
  Unload();
  delete impl_;
  impl_ = nullptr;
}

bool AsrEngine::Ready() const {
#if defined(SF_HAVE_WHISPER)
  return impl_ != nullptr && impl_->ctx != nullptr;
#else
  return false;
#endif
}

void AsrEngine::Unload() {
  std::lock_guard<std::mutex> lock(impl_->mutex);
#if defined(SF_HAVE_WHISPER)
  if (impl_->ctx != nullptr) {
    whisper_free(impl_->ctx);
    impl_->ctx = nullptr;
  }
#endif
  impl_->progress.store(0);
  impl_->cancel.store(false);
}

bool AsrEngine::Load(const std::string& model_path, std::string* error) {
#if defined(SF_HAVE_WHISPER)
  if (model_path.empty()) {
    if (error) *error = "model path is empty";
    return false;
  }
  std::lock_guard<std::mutex> lock(impl_->mutex);
  if (impl_->ctx != nullptr) {
    whisper_free(impl_->ctx);
    impl_->ctx = nullptr;
  }
  whisper_context_params params = whisper_context_default_params();
  params.use_gpu = false;  // CPU only: there is no CUDA/Metal backend on Android
  impl_->ctx = whisper_init_from_file_with_params(model_path.c_str(), params);
  if (impl_->ctx == nullptr) {
    if (error) *error = "whisper could not load the model file";
    return false;
  }
  impl_->progress.store(0);
  impl_->cancel.store(false);
  return true;
#else
  (void)model_path;
  if (error) *error = "this build has no whisper engine";
  return false;
#endif
}

void AsrEngine::Cancel() { impl_->cancel.store(true); }

int AsrEngine::Progress() const { return impl_->progress.load(); }

bool AsrEngine::Transcribe(const float* pcm, std::size_t samples, const AsrOptions& options,
                           std::vector<AsrSegment>* out, std::string* error) {
#if defined(SF_HAVE_WHISPER)
  if (pcm == nullptr || out == nullptr) {
    if (error) *error = "no audio";
    return false;
  }
  if (samples < kMinSamples) {
    if (error) *error = "audio is shorter than half a second";
    return false;
  }
  if (samples > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
    if (error) *error = "audio is too long for one pass";
    return false;
  }

  std::lock_guard<std::mutex> lock(impl_->mutex);
  if (impl_->ctx == nullptr) {
    if (error) *error = "no model is loaded";
    return false;
  }

  impl_->cancel.store(false);
  impl_->progress.store(0);

  whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.print_realtime = false;
  params.print_progress = false;
  params.print_timestamps = false;
  params.print_special = false;
  params.translate = options.translate;
  params.n_threads = std::clamp(options.threads, 1, 8);
  params.no_context = true;
  params.single_segment = false;
  params.token_timestamps = true;
  // Greedy decoding is what the small models are tuned for on phones; beam
  // search costs 2-3x the time for a marginal gain in a captioning context.
  params.greedy.best_of = 1;
  params.suppress_blank = true;

  if (!options.language.empty() && options.language != "auto") {
    params.language = options.language.c_str();
    params.detect_language = false;
  } else {
    params.language = nullptr;
    params.detect_language = true;
  }

  params.progress_callback = [](whisper_context* /*ctx*/, whisper_state* /*state*/, int progress,
                                void* user_data) {
    auto* engine = static_cast<Impl*>(user_data);
    if (engine != nullptr) engine->progress.store(progress);
  };
  params.progress_callback_user_data = impl_;

  params.abort_callback = [](void* user_data) -> bool {
    auto* engine = static_cast<Impl*>(user_data);
    return engine != nullptr && engine->cancel.load();
  };
  params.abort_callback_user_data = impl_;

  const int status = whisper_full(impl_->ctx, params, pcm, static_cast<int>(samples));
  if (status != 0) {
    if (error) {
      *error = impl_->cancel.load() ? "transcription cancelled" : "whisper failed on this audio";
    }
    impl_->progress.store(0);
    return false;
  }

  const int count = whisper_full_n_segments(impl_->ctx);
  Micros last_end = 0;
  for (int i = 0; i < count; ++i) {
    const char* raw = whisper_full_get_segment_text(impl_->ctx, i);
    if (raw == nullptr) continue;
    // whisper reports centiseconds; convert once, here.
    const Micros start_us = static_cast<Micros>(whisper_full_get_segment_t0(impl_->ctx, i)) * 10000;
    const Micros end_us = static_cast<Micros>(whisper_full_get_segment_t1(impl_->ctx, i)) * 10000;
    if (end_us <= start_us) continue;
    const Micros from = std::max(start_us, last_end);
    if (end_us <= from) continue;
    AppendTimed(out, from, end_us, std::string(raw), options.max_segment_us);
    last_end = end_us;
  }

  impl_->progress.store(100);
  if (out->empty()) {
    if (error) *error = "no speech was recognized";
    return false;
  }
  return true;
#else
  (void)pcm;
  (void)samples;
  (void)options;
  if (out != nullptr) out->clear();
  if (error) *error = "this build has no whisper engine";
  return false;
#endif
}

}  // namespace sf
