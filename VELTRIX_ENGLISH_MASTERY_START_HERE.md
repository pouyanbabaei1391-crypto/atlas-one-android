# VELTRIX AI — English Mastery | Release guide

This is an upgrade **within the uploaded Atlas Flutter project**. Original `UPDATE_TO_GITHUB.bat`, `UPDATE_TO_GITHUB.ps1`, `build.py`, `.atlas_repo_url`, native bridge and legacy sources have not been removed or renamed. The **active** UI and tutorial logic are `lib/main.dart`, `lib/screens/veltrix_home_screen.dart`, `lib/widgets/veltrix_avatar.dart` and `lib/language/*`.

## 1. Launch the language tutor on Android

1. Run Ollama on a computer or model-capable local server with adequate free RAM.
2. Install the requested model: `ollama pull gemma3:4b`.
3. Run/allow Ollama to listen on your LAN interface. For example, on Windows use a user environment variable `OLLAMA_HOST=0.0.0.0:11434`, restart Ollama, and allow TCP 11434 in **private** firewall profile only. Avoid exposing this server to the public internet.
4. In VELTRIX AI, tap the settings icon and enter your server's actual IP address, e.g. `http://192.168.1.10:11434/v1`. The placeholder address will not match most networks; **localhost on the phone is the phone, not the PC**. Phone and computer must be on a reachable LAN.
5. Tap Retry to check `/v1/models`. “MODEL ONLINE” is shown only when the requested `gemma3:4b` model is reported by the server.
6. Allow microphone permission, select the starting CEFR level, and speak English. Each lesson returns correction, upgrade, simple Persian grammar, two vocabulary entries, practice and a quiz. Subsequent answers trigger evaluation of the prior quiz.
7. Device STT and TTS depend on installed English speech recognition/TTS engines. Speech recognition may rely on a cloud provider even when **Gemma inference itself** is served from your own LAN host.

**Important:** This ZIP contains application source code, not the 4B model weights and **not a prebuilt APK**. The default install does not perform on-phone Gemma inference. The other historic English voice add-on still references Qwen3 and is retained untouched as legacy code, **not used by VELTRIX language UI**. Fully offline on-device Gemma3:4b inference would require a separate validated native GGUF/llama.cpp runtime, model-weight distribution, enough RAM and compatible mobile hardware.

## 2. Update the existing GitHub project & get APK

Repository configuration (unchanged):
`https://github.com/pouyanbabaei1391-crypto/atlas-one-android.git`

- Extract the archive on Windows **first**. Do not run the BAT inside a ZIP viewer.
- Open extracted `General Gemma34b` folder and run `UPDATE_TO_GITHUB.bat`.
- Git must be installed and authorized to push to your GitHub account. If prompted, sign in using your browser via Git Credential Manager. If authentication fails, run `gh auth login` after installing GitHub CLI, verify push access, then retry. Password authentication over HTTPS is not supported; a valid credential/token is required.
- The original BAT/PS1 connection and remote URL are preserved. Its push to `main` triggers the **added missing** `.github/workflows/build-android-apk.yml`.
- Go to `https://github.com/pouyanbabaei1391-crypto/atlas-one-android/actions` and open the latest **Build Android APK** workflow run, wait for its **successful** completion, then download `VELTRIX-AI-English-Mastery-APK` (or the original `Atlas-One-Android-APK` artifact). Extract the artifact ZIP to obtain the `.apk`, and install it on Android.
- The pipeline does not silently bypass GitHub authentication, and clicking UPDATE_TO_GITHUB is not the same as instantly receiving a signed installable APK.
- To build locally on your Windows PC: `python build.py android`, with Flutter 3.47.5, Android SDK, Java 17 installed. The output is `dist/Atlas-One-Android.apk`. Existing debug/release signing follows the original Flutter builder behavior; configure your own release keystore before a public production release.

## 3. Learning flow

```
English voice -> English STT -> user input
    -> Gemma3:4b (intent + preceding-quiz evaluation)
    -> faithful correction + natural upgrade
    -> accessible Persian grammar guidance
    -> 2 vocabulary words, collocations & examples
    -> short practice + new quiz
    -> English TTS + speaking face animation
    -> wait for student answer -> repeat
```

Model requests stream tokens to reduce waiting for receipt; structured learning cards display when the valid JSON reply is complete. Prompts and output format are in `lib/language/gemma_coach_service.dart`. `lib/language/lesson_turn.dart` contains the robust result parser. Long multi-part responses inherently require model generation time, so <1s/full-message latency is **not guaranteed**. On the host, using an appropriate GPU, keeping the model resident, and avoiding remote WAN links are the biggest practical improvements.

This supports A1–C2 **adaptive practice**; progress from A1 to C1 or C2 within one month is not a scientifically supportable promise. Actual proficiency requires sustained study and verified assessment.

## 4. CSS and responsive design

This Flutter Android app uses Dart widgets and Canvas painting, not browser CSS. To honor the supplied CSS visual reference, `web_preview/` includes a separate responsive **design preview** (`index.html`, `style.css`, `preview.js`). This browser preview is not a substitute for the Android Flutter runtime.

## 5. Honest verification notes

- The ZIP was inspected and the missing GitHub workflow was added.
- GitHub authentication, cloud APK compilation, and real-device STT/TTS/model speed must be tested on the user's account/device; they cannot be verified solely from this source archive.
- The original historical scripts are preserved so previous update/build connections remain available.
