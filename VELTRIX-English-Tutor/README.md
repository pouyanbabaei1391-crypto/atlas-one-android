# VELTRIX AI — English Micro-Tutor (Fast, Private, 30-Day Sprint)

A fully source-available Android project based on the earlier VELTRIX English Tutor. It keeps the animated facial-expression companion and an extra-large responsive conversation canvas. The app has exactly two teaching parts per successful answer: **UPGRADE** (short sentence rewrite) and **FOCUS** (one word OR one collocation OR one grammar concept, with example and recall question).

## What's changed

- On-device model switched from 4B to **Qwen3-1.7B Q4_K_M** (roughly 1.28 GB model download). Expected to reduce RAM pressure and often latency, but **10x speed and equal quality are not demonstrated**; benchmark on the actual device. Underlying model name is not displayed in the UI.
- The fast model is downloaded once, SHA-256 checked, then reused on each app launch and subsequent app update when **app data and signing identity are preserved**. Imported matching GGUF files can be selected with Android's file picker. Models stored privately by a different app are inaccessible due to Android sandboxing; the previous Gemma 4B is **not** interchangeable with the new 1.7B model.
- Frontend deliberately minimal: animated face, large chat area, voice input, reply/Stop, compact one-time model setup, small pace signal. No XP, level pickers, settings dashboard, menus, gamification missions or seven verbose lesson sections.
- Android WebView hardened: web content confined to packaged assets, network WebView requests blocked, file/content reads restricted, JavaScript bridge operations reduced to known native actions, ADB debugging of the WebView disabled. TLS/HTTPS-only model download, SHA-256 validation, backups disabled. This is a **security improvement, not an audited security guarantee**.
- 30-day *exposure* syllabus contains 3,000 English vocabulary candidates, 1,000 academic/advanced collocation patterns, and 159 grammar topics in static offline data. The vocabulary candidates are advanced-targeted but **not independently CEFR-validated word-by-word**. The application records *introduced items*, not mastery, and suggests a catch-up schedule after a missed day.

## Critical learning reality

Introducing 3,000 words + 1,000 collocations + 159 grammar topics in 30 days requires **4,159 micro lessons**, approximately **139 lessons per day** (plus reviews). This is an extreme exposure target and **does not certify C1/C2, even if every item is introduced**. A1 to C1/C2 in one month is not a valid promise. Content is intentionally one focus per message; users may need many messages or a longer plan. AI-generated explanations can make mistakes.

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
