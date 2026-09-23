#include "local_engine.hpp"
#include <algorithm>
#include <memory>
#include <mutex>
#include <stdexcept>

static std::once_flag backend;
AtlasEngine::~AtlasEngine() { clear(); }
void AtlasEngine::clear() {
    if (context) llama_free(context);
    if (model) llama_model_free(model);
    context = nullptr; model = nullptr; cache.clear();
}
bool AtlasEngine::abort_callback(void *ptr) {
    auto *self = static_cast<AtlasEngine*>(ptr);
    return self->cancelled.load() || std::chrono::steady_clock::now() > self->deadline;
}
void AtlasEngine::load(const std::string &path, int threads) {
    if (ready()) return;
    std::call_once(backend, [] { llama_backend_init(); });
    clear(); cancelled.store(false);
    auto mp = llama_model_default_params();
    mp.n_gpu_layers = 0;
    mp.load_mode = LLAMA_LOAD_MODE_MMAP;
    mp.progress_callback = [](float, void *p) { return !static_cast<AtlasEngine*>(p)->cancelled.load(); };
    mp.progress_callback_user_data = this;
    model = llama_model_load_from_file(path.c_str(), mp);
    if (!model) throw std::runtime_error("Gemma could not load. Check free RAM and the model installation.");
    auto cp = llama_context_default_params();
    cp.n_ctx = 1536;
    cp.n_batch = 256; cp.n_ubatch = 256;
    cp.n_threads = std::clamp(threads, 2, 6);
    cp.n_threads_batch = cp.n_threads;
    context = llama_init_from_model(model, cp);
    if (!context) { clear(); throw std::runtime_error("Not enough memory for the Gemma context."); }
    llama_set_abort_callback(context, abort_callback, this);
}
void AtlasEngine::generate(const std::string &prompt, int limit, const std::function<void(const std::string&)> &emit) {
    if (!ready()) throw std::runtime_error("Install and load Gemma before starting voice chat.");
    deadline = std::chrono::steady_clock::now() + std::chrono::seconds(45);
    const auto *vocab = llama_model_get_vocab(model);
    int count = llama_tokenize(vocab, prompt.data(), (int)prompt.size(), nullptr, 0, true, true);
    if (count >= 0) throw std::runtime_error("Empty prompt.");
    std::vector<llama_token> tokens(-count);
    count = llama_tokenize(vocab, prompt.data(), (int)prompt.size(), tokens.data(), (int)tokens.size(), true, true);
    if (count <= 0) throw std::runtime_error("Prompt tokenization failed.");
    tokens.resize(count);
    limit = std::clamp(limit, 8, 256);
    if (tokens.size() + limit >= llama_n_ctx(context)) throw std::runtime_error("This message is too long for mobile voice mode. Please shorten it.");
    auto memory = llama_get_memory(context);
    size_t common = 0;
    while (common < tokens.size() && common < cache.size() && tokens[common] == cache[common]) common++;
    if (common == tokens.size()) common--;
    if (!llama_memory_seq_rm(memory, 0, (llama_pos)common, -1)) { llama_memory_clear(memory, true); common = 0; }
    cache.resize(common);
    auto decode = [&](llama_token *data, int n) {
        if (abort_callback(this)) throw std::runtime_error(cancelled.load() ? "Generation cancelled." : "Local inference timed out on this device.");
        if (llama_decode(context, llama_batch_get_one(data, n)) != 0) {
            llama_memory_clear(memory, true); cache.clear();
            throw std::runtime_error(cancelled.load() ? "Generation cancelled." : "Local inference stopped. Try a shorter question or free some RAM.");
        }
        cache.insert(cache.end(), data, data + n);
    };
    for (size_t i = common; i < tokens.size(); i += 128) decode(tokens.data() + i, std::min<int>(128, (int)tokens.size() - (int)i));
    std::unique_ptr<llama_sampler, decltype(&llama_sampler_free)> sampler(llama_sampler_init_greedy(), llama_sampler_free);
    for (int i = 0; i < limit; ++i) {
        if (abort_callback(this)) throw std::runtime_error(cancelled.load() ? "Generation cancelled." : "Local response time limit reached.");
        auto token = llama_sampler_sample(sampler.get(), context, -1);
        if (llama_vocab_is_eog(vocab, token)) break;
        std::vector<char> piece(256);
        int n = llama_token_to_piece(vocab, token, piece.data(), (int)piece.size(), 0, false);
        if (n < 0) { piece.resize(-n); n = llama_token_to_piece(vocab, token, piece.data(), (int)piece.size(), 0, false); }
        if (n > 0) emit(std::string(piece.data(), n));
        decode(&token, 1);
    }
}
