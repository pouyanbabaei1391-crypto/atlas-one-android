ATLAS LOCAL - QWEN3 1.7B Q4_K_M, VERSION 0.6.0+6

THIS ZIP IS SOURCE CODE, NOT AN APK AND NOT THE MODEL WEIGHTS.
The bundled build downloads and verifies the exact 1,107,409,376-byte Qwen3 1.7B Q4_K_M model, splits it into APK assets, and packages it with the Android app. The Slim build downloads the same verified model during Local AI setup. An actual Android APK has not been produced or device-tested in this editing environment.

INSTALL THE NEW EDITION
1. Extract the complete ZIP.
2. Run the original UPDATE_TO_GITHUB.bat. Its contents and saved repository address are unchanged.
3. Open GitHub Actions, run Build Atlas Android Slim Qwen3 APK once, and wait for it to finish.
4. Download Atlas-One-Android-SLIM-QWEN3-APK, extract it, and install its APK on a 64-bit ARM phone running Android 9 or newer.
5. Confirm the app header is Atlas Local · Qwen3.
6. Open Prepare your local AI. Read and accept the Qwen3 Apache 2.0 license, then tap Install and prepare Qwen3. The Slim edition downloads with resume support and verifies the exact SHA-256 before loading. Keep the setup screen open.
7. Wait for Ready on this phone. Return and start voice chat.

Free at least 1.5 GB of data storage IN ADDITION to the APK. Installation needs both the APK and extracted model. A device may fail or be terminated by Android if it cannot supply enough memory. Readiness is a load check, not a guarantee against future memory pressure.
After a process restart, model files stay installed but need loading/warming again. Local AI setup shows Load Qwen3 on this phone.

HOW THE CORE WORKS
Android speech recognition -> recognized English text -> direct JNI call -> in-process llama.cpp -> Qwen3 1.7B Q4_K_M inference -> incremental reply text -> complete-sentence native English TTS.
Local mode is the Android default. It does not send chat or embedding requests to an AI server, laptop IP, Ollama service or API key. There is no hidden fallback to a remote server. Remote mode remains available explicitly in Settings with the previous connection settings preserved.

STT converts speech to text. Qwen3 generates and displays the answer token by token. TTS waits for sentence-ending punctuation and then speaks the complete sentence smoothly. The local native runtime is built into the app; Ollama itself is not needed on the phone.

MODEL AND RUNTIME IDENTITY
Model: unsloth/Qwen3-1.7B-GGUF/Qwen3-1.7B-Q4_K_M.gguf
Size: 1107409376 bytes
SHA-256: ba491cf470c3cadc624e4c8d6c9a27c998809e8ba8eb938d1689ae87e024b6b7
llama.cpp revision: c350a40bbd0ba0658793f0fc74a8b3b3ab65135e
Runtime: CPU inference, 2-6 threads, 1536-token context, up to 256 generated tokens, token streaming, reusable prompt cache and cancellation. Fast voice uses Qwen3 non-thinking mode with temperature 0.7, top-p 0.8 and top-k 20. This does not claim GPU or NPU acceleration.

SMALL-INSTALLER OPTION
Manually run the GitHub workflow with bundle_model disabled to build a smaller APK. That variant downloads the model once inside Local AI setup and supports resuming partial downloads. It still performs the same SHA-256 check. Default push builds include the weights. Do not expect the small installer to work locally before the model has downloaded.
For a local build with weights, use BUILD_LOCAL_GEMMA_ANDROID.bat. The existing BUILD_ANDROID scripts are preserved and still build the original edition. Existing English build entry now uses the local edition and bundles by default.

PERFORMANCE
Model loading and a short warm-up occur in setup before enabling voice chat. Reply text streams token by token; TTS receives complete sentences instead of individual tokens or words. The UI records the native TTS start callback time for each response as Speech started in ... ms. This is an engine callback measurement, not a microphone recording of physical audible onset.
Sub-second complete answers or audio onset cannot be guaranteed on an arbitrary phone. Initial model installation/loading, speech endpoint detection, prompt length, RAM, CPU speed, thermal throttling and TTS all contribute. Background model generation has a 45-second native time budget with cancellation checks; this is a failure bound, not a performance target.

RETAINED FEATURES AND LIMITS
All 42 files from the original uploaded project are byte-identical. New behavior is in the additive build overlay; old overlay versions are archived under english_voice_addon/history.
Microphone foreground service, notification stop, input meter, English TTS, retries and GitHub updater remain.
Local mode currently handles TEXT/VOICE, not local image inference. Camera/screen analysis and remote semantic embeddings remain available in explicit server mode; they have not been removed. Encrypted conversation storage stays enabled in local mode, with a compact recent history in the prompt. Local semantic embeddings are not implemented.
Qwen3 inference is offline after installation. Android speech recognition may still need network access if the device lacks an on-device English recognition model; TTS also needs an installed English voice. Background sessions can be stopped by Force stop, process termination, reboot or vendor battery policies.

VALIDATION ACTUALLY PERFORMED
- Verified Python build scripts compile and the additive staging overlay is generated.
- Verified pinned model URL, exact byte size, and SHA-256 metadata are consistent in the build and Android installer.
- Verified the staged Qwen ChatML prompt, non-thinking switch, token stream, and sentence-only speech buffer are present.
Flutter tests, full Android/Gradle compilation, APK installation, full model download, and real phone microphone/TTS/local-inference latency were NOT executed here. Those remain device/build validation requirements.

The pre-existing LOCAL_GEMMA_VERIFICATION.json and validation logs are retained unchanged as historical Gemma records; they are not Qwen3 test claims.

REFERENCES
https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md
https://huggingface.co/Qwen/Qwen3-1.7B
https://huggingface.co/unsloth/Qwen3-1.7B-GGUF
License/notice copies are packaged under native Android assets/gemma.
