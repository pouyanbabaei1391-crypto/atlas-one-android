## Windows uploader safety hotfix

**Always extract the complete ZIP first.** The root `UPDATE_GITHUB_WINDOWS.bat` now stops if the Android project is missing and never recursively calls itself. GitHub CLI, if installed, prompts browser authentication; otherwise Git Credential Manager should prompt when Git pushes. APK generation still depends on GitHub Actions build success.

---

# VELTRIX AI — English Intelligence

**A genuine Android project** with the VELTRIX ExperienceSpace robot, local on-device GGUF inference using the *official* `llama.cpp` Android JNI inference module, Android voice recognition and text-to-speech, adaptive learning prompts, and a GitHub Actions APK builder.

Founder / brand concept: **Parham Babaei — VELTRIX AI**.

> IMPORTANT: This ZIP contains SOURCE CODE and a CI build workflow. It does **not** contain a compiled, device-tested APK or a 2.4 GB model. Building requires Android SDK/NDK, Gradle and the official llama.cpp library to be downloaded. The GitHub workflow is provided but has NOT been executed in this environment. Do not claim a successful device test until GitHub Actions builds and you install the APK on a phone.

## 1. Features and architecture

```text
                        VELTRIX English Intelligence
                        ┌────────────────────────────┐
 Voice → Android STT  ───▶ Intent + context prompt    │
 Typed text ─────────────▶                            │
                        │ On-device MODEL            │
                        │ Gemma 3 4B GGUF / llama.cpp │
                        │ 1. Review & quiz grading   │
                        │ 2. Correct every sentence  │
                        │ 3. Advanced rewrite        │
                        │ 4. Simple grammar lesson   │
                        │ 5. 3 words/collocations    │
                        │ 6. Guided practice         │
                        │ 7. New quiz → next turn    │
                        └─────────────┬──────────────┘
                                      │
                               Android native TTS
                                      │
                              VELTRIX speaks aloud
```

- Website-style dark graphite / teal design that reproduces the **original animated VELTRIX robot** from the earlier ExperienceSpace website. Mobile portrait responsive. CSS/SVG only — no internet-dependent graphics.
- An interactive spoken / written practice loop, seven teaching cards per reply, quiz grading at the start of the following reply, CEFR self-selection, and training focus.
- Persistent local XP and study streak **as engagement indicators** (not an objectively measured CEFR proficiency).
- Private GGUF file in Android app storage and explicit opt-in download or user-file import. The model remains available after download without Ollama or cloud inference.
- Official llama.cpp Android example **InferenceEngine** handles GGUF loading and streaming generation; its sources are fetched by the bootstrap script.
- Android SpeechRecognizer (English preferred) and OS TextToSpeech. `EXTRA_PREFER_OFFLINE` is requested for STT, but recognition may still be cloud-assisted, depending on the phone's speech provider and downloaded speech packs. TTS voices may also need separate installation.
- Stop processing and TTS, restart lesson (unload/reload GGUF to clear model KV cache), and reinstall after a failed model download.
- Public interface uses only the term **MODEL** and the identity **VELTRIX AI**. Model details remain visible in this README for technical and license compliance.

## 2. Phone and model requirements

- **Android 13+ (API 33+)**, **64-bit ARM** phone.
- **8 GB RAM or more recommended**, 12 GB is safer. 4 GB parameter models may be too slow, overheat, or not load on older devices. Specific device compatibility is not verified.
- At least **3 GB of free internal storage** for the download (in addition to room for Android system, app, and temporary files).
- The app downloads (once) `unsloth/gemma-3-4b-it-GGUF / gemma-3-4b-it-Q4_0.gguf` from Hugging Face (approx **2.37 GB**), then checks SHA-256 before loading it. The quantized model weights are **NOT inside the APK**.
- The downloaded GGUF hash is specified in `ModelDownloader.kt` to detect corrupt files. The model has its own license (Google Gemma); review model terms before distributing commercially.

**Model source (manual import alternative):** https://huggingface.co/unsloth/gemma-3-4b-it-GGUF/blob/main/gemma-3-4b-it-Q4_0.gguf

**If Hugging Face cannot be reached from the phone:** download the above exact GGUF file on a computer, transfer it to the phone's Downloads folder, tap `Import GGUF` inside VELTRIX. The SHA-256 verification requires the correct exact file.

## 3. One-click GitHub upload and automatic APK build

**PRECONFIGURED DESTINATION:** https://github.com/pouyanbabaei1391-crypto/atlas-one-android

1. Extract this ZIP, preserving its `VELTRIX-English-Tutor/` directory structure.
2. Double-click **`UPDATE_GITHUB_WINDOWS.bat`**. You do **not** need to enter the GitHub repository address, your Git name/email or press Y to confirm. It is already preconfigured.
3. The script clones your existing `atlas-one-android` default branch, writes only `VELTRIX-English-Tutor/` and `.github/workflows/veltrix-english-tutor.yml`, commits and pushes WITHOUT force-push and without changing Atlas One project files.
4. This push automatically starts **Actions → VELTRIX English Tutor APK**. The GitHub workflow builds a debug ARM64 APK and uploads it both as an **Actions Artifact** and a new **GitHub Release (pre-release)**.
5. Once Actions completes successfully, get **VELTRIX-English-Tutor.apk** at: https://github.com/pouyanbabaei1391-crypto/atlas-one-android/releases . You can also download the artifact on the workflow run page. The APK is produced *after* the GitHub workflow passes, not instantaneously when you double-click.
6. Install APK on Android, then use **Install MODEL** inside the app for local Gemma GGUF inference.

**Prerequisites:** Git for Windows, GitHub credentials with repository write access, working internet, GitHub Actions enabled, and permission for Actions to create releases. Git Credential Manager may open a browser sign-in **once**; no password or token is embedded in the BAT or PowerShell files. If the branch is protected, a direct push can be rejected rather than bypassing protection. The workflow has not been run against your GitHub account or on a physical Android device here. The APP build may need troubleshooting, especially its native llama.cpp dependency.

Each successful upload writes a new build-request marker so the GitHub Actions workflow triggers even when the source code itself has not changed.

## 4. Build in Android Studio / on a Windows computer

1. Install Android Studio, JDK 17, Git, Android SDK 36, NDK `29.0.13113456`, and CMake `3.31.6`.
2. In PowerShell, from the extracted project root:

   ```powershell
   .\scripts\bootstrap_llama.ps1
   ```

   This downloads the **official** llama.cpp repository at the **v0.6.0** release tag into the local `vendor` folder, which is intentionally excluded from this ZIP. Internet access is required to fetch sources and Gradle dependencies.

3. Open the folder in Android Studio and wait for Gradle sync.
4. Run the app on your ARM64 Android phone or build `:app:assembleDebug`.
5. Find APK at `app/build/outputs/apk/debug/app-debug.apk`.

Do not manually clone unrelated model runtime repositories: this project references the specific official Android library at `vendor/llama.cpp/examples/llama.android/lib`.

## 5. Full teaching cycle

Each message is sent to the model with a behavioral instruction template from `TutorPrompts.kt`:

1. REVIEW — meaning and grade the previous quiz answer, if applicable.
2. CORRECTION — corrected sentences, with “Already correct” when appropriate.
3. UPGRADE — a more natural / advanced rewrite preserving meaning.
4. GRAMMAR — one rule with a simple explanation and examples.
5. VOCABULARY — exactly three words / collocations, short Persian gloss, usage, examples and one pronunciation tip.
6. PRACTICE — a targeted drill.
7. QUIZ — one new question and wait for the student's next answer.

Example: `I go to school yesterday.`

The answer is generated by the on-device language model. **It is not a fixed canned teaching response.** Outputs may occasionally break the seven-section format; the UI then displays the raw result and says it is unstructured. This is a prototype, not a validated pedagogy product.

## 6. Limitations and honest expectations

- A1 → C1/C2 **within one month cannot be guaranteed or expected for most learners**. Actual proficiency requires consistent practice, measured comprehension, writing, listening, and speaking over a long period. The levels in the interface are learner-selected, not a certification.
- This does **NOT** fine-tune or train Gemma 3; it loads the existing instruction-tuned quantized model with a domain-specific teaching prompt.
- Native STT depends on the installed Android recognizer and may use online recognition services. Local Gemma inference can work offline after installation.
- Speech-to-text is not the same as phoneme-level pronunciation scoring. The app can correct **recognized text**, but does not provide validated accent or phonetic accuracy assessment.
- Actual device performance, llama.cpp v0.6.0 Android library build, GGUF loading, and model fit in memory have **not been verified on a physical Android phone** in this environment. CI must pass before calling the app build complete.
- The first start requires a large model download; storing and loading model weights on the device may be slow. Battery and heat matter.
- Model instructions aim to cover all seven teaching stages, but generative outputs are not guaranteed correct; learners should double-check high-stakes exam material.
- The code does not stream audio directly into a local STT model; it invokes the Android speech recognizer. There is no background microphone recording when the app is closed.

## 7. Privacy and security

No API keys. No default outbound LLM inference requests. The Android app makes network calls only when obtaining the GGUF model (and Android speech recognizer may make cloud calls depending on OS service). All lesson text goes through app-local model inference. The UI saves XP, selected CEFR self-level and training focus in its local WebView storage; it does not upload transcripts.

The WebView JavaScript bridge is only loaded from the app's trusted `file:///android_asset/` pages, with external navigation blocked. Do not allow untrusted remote webpages to use this bridge.

## 8. Contents

```text
VELTRIX-English-Tutor/
├── .github/workflows/build-apk.yml   # GitHub Actions → APK artifact
├── UPDATE_GITHUB_WINDOWS.bat          # Push repo updates to GitHub
├── scripts/bootstrap_llama.sh/.ps1    # Official llama.cpp Android library setup
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml
├── app/build.gradle.kts
├── app/src/main/AndroidManifest.xml
├── app/src/main/java/ai/veltrix/tutor/
│   ├── MainActivity.kt                # WebView, local inference, STT, TTS
│   ├── TutorPrompts.kt                # Seven-stage adaptive tutor prompt
│   └── ModelDownloader.kt             # Resumable GGUF download and SHA-256
├── app/src/main/assets/
│   ├── index.html                     # ExperienceSpace learning UI
│   ├── legacy-visual.css              # Preserved VELTRIX robot animation
│   ├── tutor.css                      # Responsive mobile app UI
│   └── tutor.js                       # UI and native-event layer
└── tests/                              # Source/UI smoke tests
```

Source references: https://github.com/ggml-org/llama.cpp (v0.6.0), https://huggingface.co/unsloth/gemma-3-4b-it-GGUF . License notices for these external works remain under their respective repositories and model pages.


## One-click build reliability update (2026-10-09)
Each click creates `LAST_BUILD_REQUEST.txt`, thus a fresh GitHub push triggers the dedicated workflow even when source content is unchanged. Source upload does not itself compile APK. The optional GitHub CLI monitor watches the build and downloads the Actions artifact to `VELTRIX_APK_DOWNLOAD`; without gh, follow the Actions link. The workflow uploads an APK artifact after successful compilation and optionally creates a Release. Failures produce an actionable `VELTRIX-Build-Error-Log` artifact.
