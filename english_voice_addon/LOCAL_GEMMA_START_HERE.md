ATLAS LOCAL - GEMMA 3 4B, VERSION 0.6.0+6

THIS ZIP IS SOURCE CODE, NOT AN APK AND NOT THE MODEL WEIGHTS.
The default GitHub workflow now downloads and verifies the real 2,489,758,112-byte Gemma model while building, splits it into APK assets, and packages it with the Android app. This avoids pushing multi-gigabyte weights into your GitHub source repository. The resulting APK is therefore larger than 2.49 GB. An actual Android APK has not been produced or device-tested in this editing environment.

INSTALL THE NEW EDITION
1. Extract the complete ZIP.
2. Run the original UPDATE_TO_GITHUB.bat. Its contents and saved repository address are unchanged.
3. Wait for Build Atlas Android APK in GitHub Actions. Model download and native compilation make this a larger build than before.
4. Download Atlas-One-Android-APK, extract it, and install its APK on a 64-bit ARM phone running Android 9 or newer.
5. Confirm the app header is Atlas Local · Gemma 3.
6. Open Prepare your local AI. Read and accept the Gemma terms, then tap Install and prepare Gemma. The bundled edition copies and verifies its included model without a model download on the phone. Keep the setup screen open.
7. Wait for Ready on this phone. Return and start voice chat.

Free at least 3 GB of data storage IN ADDITION to the large APK. Installation needs both the APK and extracted model. Model inference also uses several GB of RAM. A device may fail or be terminated by Android if it cannot supply enough memory. Readiness is a load check, not a guarantee against future memory pressure.
After a process restart, model files stay installed but need loading/warming again. Local AI setup shows Load Gemma on this phone.

HOW THE CORE WORKS
Android speech recognition -> recognized English text -> direct JNI call -> in-process llama.cpp -> real Gemma 3 4B IT Q4_K_M inference -> incremental reply text -> native English TTS.
Local mode is the Android default. It does not send chat or embedding requests to an AI server, laptop IP, Ollama service or API key. There is no hidden fallback to a remote server. Remote mode remains available explicitly in Settings with the previous connection settings preserved.

STT converts speech to text. TTS speaks the generated answer. Gemma is the reasoning/language model between them. The local native runtime is built into the app; Ollama itself is not needed on the phone. The model belongs to the same Gemma 3 4B instruction-tuned family requested as gemma3:4b, stored in a verified GGUF Q4_K_M representation.

MODEL AND RUNTIME IDENTITY
Model: bartowski/google_gemma-3-4b-it-GGUF/google_gemma-3-4b-it-Q4_K_M.gguf
Size: 2489758112 bytes
SHA-256: 4996030242583a40aa151ff93f49ed787ac8c25e4120c3ae4588b2e2a7d1ae94
llama.cpp revision: c350a40bbd0ba0658793f0fc74a8b3b3ab65135e
Runtime: CPU inference, maximum 4 threads, 2048-token context, up to 192 generated tokens per app response, streaming, reusable prompt cache and cancellation. This does not claim GPU or NPU acceleration.

SMALL-INSTALLER OPTION
Manually run the GitHub workflow with bundle_model disabled to build a smaller APK. That variant downloads the model once inside Local AI setup and supports resuming partial downloads. It still performs the same SHA-256 check. Default push builds include the weights. Do not expect the small installer to work locally before the model has downloaded.
For a local build with weights, use BUILD_LOCAL_GEMMA_ANDROID.bat. The existing BUILD_ANDROID scripts are preserved and still build the original edition. Existing English build entry now uses the local edition and bundles by default.

PERFORMANCE
Model loading and a short warm-up occur in setup before enabling voice chat. Replies stream to TTS rather than waiting for the full answer. The UI records the native TTS start callback time for each response as Speech started in ... ms. This is an engine callback measurement, not a microphone recording of physical audible onset.
Sub-second complete answers or audio onset cannot be guaranteed on an arbitrary phone. Initial model installation/loading, speech endpoint detection, prompt length, RAM, CPU speed, thermal throttling and TTS all contribute. Background model generation has a 45-second native time budget with cancellation checks; this is a failure bound, not a performance target.

RETAINED FEATURES AND LIMITS
All 42 files from the original uploaded project are byte-identical. New behavior is in the additive build overlay; old overlay versions are archived under english_voice_addon/history.
Microphone foreground service, notification stop, input meter, English TTS, retries and GitHub updater remain.
Local mode currently handles TEXT/VOICE, not local image inference. Camera/screen analysis and remote semantic embeddings remain available in explicit server mode; they have not been removed. Encrypted conversation storage stays enabled in local mode, with a compact recent history in the prompt. Local semantic embeddings are not implemented.
Gemma reasoning is offline after installation. Android speech recognition may still need network access if the device lacks an on-device English recognition model; TTS also needs an installed English voice. Background sessions can be stopped by Force stop, process termination, reboot or vendor battery policies.

VALIDATION ACTUALLY PERFORMED
- Compiled the exact new C++ inference core against the pinned llama.cpp revision on the host.
- Downloaded the real 2.49 GB model and verified its full SHA-256.
- Executed cold/warm inference: both returned Four. to a math question.
- Executed a useful English answer with valid reply/actions JSON for Why is the sky blue?.
- Executed native cancellation during real generation: passed.
- Syntax-compiled the JNI bridge against OpenJDK JNI headers.
- Executed model bundler tests: reconstruction of split parts, maximum part size, rejection/cleanup of corrupt data and replacement of an existing staging file.
- Checked staged CMake/ARM64/asset packaging injection, original-file hashes, manifest and workflow/Python syntax; parsed the Dart and Kotlin sources.
Flutter tests, full Android/Gradle compilation, APK installation and real phone microphone/TTS/local-inference latency were NOT executed here. Those remain device/build validation requirements. Cloud builds run Dart analysis and tests before building.

The source includes actual test logs and LOCAL_GEMMA_VERIFICATION.json. Host first-token timings are not phone or end-to-end voice benchmarks.

REFERENCES
https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md
https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF
https://ai.google.dev/gemma/terms
https://ai.google.dev/gemma/prohibited_use_policy
License/notice copies are packaged under native Android assets/gemma.
