#pragma once
#include "llama.h"
#include <atomic>
#include <chrono>
#include <functional>
#include <string>
#include <vector>

class AtlasEngine {
 public:
  ~AtlasEngine();
  void load(const std::string &path, int threads);
  void generate(const std::string &prompt, int max_tokens, const std::function<void(const std::string&)> &emit);
  void cancel() { cancelled.store(true); }
  void reset_cancel() { cancelled.store(false); }
  bool ready() const { return context != nullptr; }
 private:
  llama_model *model = nullptr;
  llama_context *context = nullptr;
  std::vector<llama_token> cache;
  std::atomic<bool> cancelled{false};
  std::chrono::steady_clock::time_point deadline;
  static bool abort_callback(void *self);
  void clear();
};
