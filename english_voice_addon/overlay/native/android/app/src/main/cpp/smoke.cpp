#include "local_engine.hpp"
#include <iostream>
#include <chrono>
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    try {
        AtlasEngine engine;
        engine.load(argv[1], 4);
        for (int i = 0; i < 2; ++i) {
            auto start = std::chrono::steady_clock::now();
            bool first = true;
            std::string reply;
            engine.generate("<|im_start|>system\nAnswer briefly in English. /no_think<|im_end|>\n<|im_start|>user\nWhat is two plus two? /no_think<|im_end|>\n<|im_start|>assistant\n", 64, [&](const std::string &s) {
                if (first) { std::cerr << "First token ms: " << std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-start).count() << "\n"; first=false; }
                reply += s; std::cout << s << std::flush;
            });
            std::cout << "\n";
            if (reply.empty()) return 3;
        }
        engine.reset_cancel();
        std::string json;
        engine.generate("<|im_start|>system\nReply in JSON with fields reply and actions. Keep actions empty. /no_think<|im_end|>\n<|im_start|>user\nWhy is the sky blue? Answer in one sentence. /no_think<|im_end|>\n<|im_start|>assistant\n", 128, [&](const std::string &s) { json += s; });
        std::cout << "JSON_REPLY=" << json << "\n";
        engine.reset_cancel();
        bool interrupted = false;
        try {
            engine.generate("<|im_start|>user\nCount from one to a hundred. /no_think<|im_end|>\n<|im_start|>assistant\n", 128, [&](const std::string &) { engine.cancel(); });
        } catch (const std::exception &) { interrupted = true; }
        if (!interrupted) return 4;
        std::cout << "CANCEL_TEST=PASS\n";
    } catch (const std::exception &e) { std::cerr << e.what() << "\n"; return 1; }
}
