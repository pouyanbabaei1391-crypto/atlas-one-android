# VELTRIX AI — English Tutor (Fast, Private, Three-Stage Learning)

A fully source-available Android project based on the earlier VELTRIX English Tutor. It keeps the animated facial-expression companion and an extra-large responsive conversation canvas. The app has exactly two teaching parts per successful answer: **ANSWER** (a concise corrected and advanced rewrite) and **PRACTICE** (one staged lesson, at most 15 logical lines, with one exercise).

## What's changed

- On-device model switched from 4B to **Qwen3-1.7B Q4_K_M** (roughly 1.28 GB model download). Expected to reduce RAM pressure and often latency, but **10x speed and equal quality are not demonstrated**; benchmark on the actual device. Underlying model name is not displayed in the UI.
- The fast model is downloaded once, SHA-256 checked, then reused on each app launch and subsequent app update when **app data and signing identity are preserved**. Imported matching GGUF files can be selected with Android's file picker. Models stored privately by a different app are inaccessible due to Android sandboxing; the previous Gemma 4B is **not** interchangeable with the new 1.7B model.
- Frontend deliberately minimal: animated face, large chat area, voice input, reply/Stop, compact one-time model setup, small pace signal. No XP, level pickers, settings dashboard, menus, gamification missions or seven verbose lesson sections.
- Android WebView hardened: web content confined to packaged assets, network WebView requests blocked, file/content reads restricted, JavaScript bridge operations reduced to known native actions, ADB debugging of the WebView disabled. TLS/HTTPS-only model download, SHA-256 validation, backups disabled. This is a **security improvement, not an audited security guarantee**.
- 30-day *exposure* syllabus contains 3,000 English vocabulary candidates, 1,000 academic/advanced collocation patterns, and 159 grammar topics in static offline data. The vocabulary candidates are advanced-targeted but **not independently CEFR-validated word-by-word**. The application records *introduced items*, not mastery, and suggests a catch-up schedule after a missed day.

## Critical learning reality

The lesson cycle is **10 unseen vocabulary items → 1 advanced grammar topic → 10 unseen collocations**, repeated. With 3,000 words, covering all vocabulary alone requires 300 vocabulary turns; keeping the strict three-turn cycle means **at least 900 conversations, about 30 per day for 30 days**, with repeated grammar/collocation review after those pools finish. This is an extreme exposure target and **does not certify C1/C2 or lasting retention**, particularly from A1 in a month. AI-generated explanations and examples can be incorrect; no model is guaranteed to obey the 10-entry format in every turn. In that case the lesson is shown but not marked as introduced, so the next turn repeats its assigned content.

## English-only Answer & Practice

- **ANSWER:** one concise English correction / improved version of the student's message, preserving the meaning.
- **PRACTICE:** vocabulary batches of 10 entries (each term, short English definition, short example); the next turn is an advanced grammar explanation with examples; the next turn is a batch of 10 professional collocations. Each ends with exactly one **Exercise:** question.
- The curriculum index and introduced-item IDs persist in Android WebView local storage. The next vocabulary batch begins where the previous one stopped. Advanced grammar topics are prioritized. Once a pool is exhausted, those turns switch to review.
- Practice is capped at **15 explicit logical lines**; on narrow phones, long example lines are horizontally scrollable rather than wrapped into many physical rows. The model must satisfy the required output format for the lesson to count.
- Lessons run with a quantized local model. Ten-item responses are longer than old micro-lessons and may be slower; do not assume the 10× speed target is achieved.

## Model / privacy

GGUF download: `https://huggingface.co/Antigma/Qwen3-1.7B-GGUF/resolve/main/qwen3-1.7b-q4_k_m.gguf` (Apache 2.0 based on model card), expected SHA-256 `a7f6720f68f4a4567ebf7e3257041dd0b72077b518efe56890aec3516b59b9de`. Private text inference happens entirely on-device; Android's OS speech recognition may rely on external services despite the offline-preferred flag. Install an on-device recognition service/language pack and offline TTS voice if full speech privacy is important. The app does not upload chat content to its own server.

If the exact same fast model has already been installed and verified in this app's private storage, its download is skipped. For files in Downloads or elsewhere, use **Import GGUF**. An Android app cannot silently read another app's private model data.

**Important:** GitHub Actions produces a **debug-signed APK**; GitHub runner signing keys may change between builds. Android may refuse in-place updates and uninstalling may erase private model data. For reliable updates retaining data and avoiding repeated downloads, set up your own persistent, secret release signing key. Never commit its password or the private keystore to the repository. See `SIGNING_AND_UPDATES.md`.

## Build / GitHub

1. Right-click ZIP → **Extract All**. Never double-click the BAT inside WinRAR.
2. Open the extracted top-level folder and run `UPDATE_GITHUB_WINDOWS.bat` on Windows with Git installed. It targets `https://github.com/pouyanbabaei1391-crypto/atlas-one-android` and adds VELTRIX in a dedicated folder; it avoids force pushes.
3. GitHub Actions: workflow **VELTRIX English Tutor APK** builds the project, using the GitHub runner Android SDK/NDK, Java 17 and Gradle.
4. Only **if the run turns green**, download `VELTRIX-English-Tutor.apk` from Artifacts; signing and compilation were **not executed end-to-end in this environment**.
5. Install on ARM64 Android 13+ with sufficient free RAM and storage. In the app tap **Install MODEL** or **Import GGUF**.

## Licensing and attribution

- Qwen3-1.7B-GGUF model: Apache 2.0 model family, see https://huggingface.co/Qwen/Qwen3-1.7B-GGUF and https://huggingface.co/Antigma/Qwen3-1.7B-GGUF.
- Vocabulary list: combined handpicked entries and original selection/ranking of candidate words derived during build from the installed **TextBlob** lexical lists and CMU pronunciation dictionary. It does not reproduce the Oxford or Cambridge proprietary CEFR word list or claim external validation.
- Collocations: original manually grouped usage patterns; contextual judgment is required.
- Grammar: original topic taxonomy; the explanations are generated at practice time, not a pre-reviewed exhaustive textbook.

## What is not claimed

No actual APK binary is included. No independently verified 10x speedup, complete security audit, certified CEFR progression, stable updater key or correctness guarantee. JavaScript demo without the APK can show the interface, but it cannot run the model.
