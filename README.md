# Atlas One Mobile AI — Full Fix v4

A mobile-first Persian AI application foundation for **Android + iOS**, designed around explicit user permissions, encrypted memory, visual context and user-approved application actions.

## Core capabilities preserved and repaired

- **Persian Microphone AI** — STT → LLM → TTS conversational loop.
- **Screen Vision** — continuously refreshes the latest screen frame after the OS capture-consent flow; the AI receives the current frame when the user speaks/asks for screen analysis.
- **Camera Vision** — front-camera preview and current-frame visual reasoning.
- **Autonomous Work with Applications** — Android enumerates launchable apps; the user selects an allow-list; the AI may open only those selected apps and may open approved `http`, `https`, `mailto`, `tel`, `sms`, and `geo` URIs. Deeper app work must use that app's official API / Intent / Deep Link.
- **Short-Term Memory** — current conversation context.
- **Long-Term Memory** — encrypted local SQLite message store plus optional semantic retrieval from an embeddings endpoint.
- **Conversation persistence** — messages are stored whenever Memory is enabled (enabled by default).
- **Voice shutdown / Kill Switch** — phrases such as `خاموش شو`, `همه چیز رو خاموش کن`, `خداحافظ اطلس` cause Atlas to stop listening, say `خداحافظ <نام کاربر>`, then stop Camera, Screen Vision and all app-action allow-list access. Android 13+ also requests self-revocation of Camera/Microphone permissions.
- **OpenAI-compatible endpoint** — defaults to `gemma3:4b`; endpoint/model/API key are configurable.
- **Android + iOS native bridges** — Android MediaProjection + package launch; iOS ReplayKit/system URL integrations.

## The simple Android build/update flow

You specifically asked that **Update to GitHub must remain in the project**. It is now a first-class workflow:

```text
UPDATE_TO_GITHUB.bat
```

The script:

1. remembers your GitHub repository URL after the first run;
2. creates a clean publishing clone of the existing repository;
3. copies the latest Atlas project into it;
4. commits changes without destroying repository history;
5. pushes `main`;
6. opens GitHub Actions automatically;
7. the push automatically starts `Build Atlas Android APK`.

Download the finished artifact:

```text
Actions
→ Build Atlas Android APK
→ successful run
→ Artifacts
→ Atlas-One-Android-APK
→ Atlas-One-Android.apk
```

No Android Studio installation is required on your local Windows machine for this cloud path.

Compatibility aliases are also kept:

```text
UPLOAD_TO_GITHUB.bat
PUSH_FINAL_FIXED_BUILD.bat
UPDATE_AND_BUILD_ANDROID.bat
```

All route to the same safe updater.

## Local Android build

If your machine already has Flutter + Java + Android SDK:

```powershell
.\BUILD_ANDROID.ps1
```

or double-click:

```text
BUILD_ANDROID.bat
```

Output:

```text
dist/Atlas-One-Android.apk
```

## iPhone / iOS

The iOS source is included and is generated/patched by `build.py`. Flutter 3.47's UIScene lifecycle is handled through `FlutterImplicitEngineDelegate`.

Local signed build on a Mac:

```bash
./BUILD_IOS.command
```

A real installable iPhone IPA requires an Apple Developer signing identity and provisioning profile. For general users, distribute via **TestFlight/App Store**. Apple does not allow an arbitrary unsigned IPA received in a messenger to install like an Android APK.

A manual GitHub Actions workflow called **Validate Atlas iOS Build** is also included. It produces an **unsigned validation artifact**, not a directly installable iPhone package.

## Platform boundaries that the code does not fake

### Android

Atlas can enumerate launchable applications, display them to the user, maintain a user-selected allow-list, launch selected packages, observe the screen through MediaProjection after explicit consent, and use official intents/deep links/APIs.

It intentionally does not contain a hidden AccessibilityService click-bot. Unrestricted covert UI control is neither a stable nor appropriate general-purpose mobile integration strategy.

### iOS

iOS does not allow a normal third-party application to enumerate and arbitrarily operate every installed app. Atlas exposes documented system integrations and can be extended with App Intents, Shortcuts, URL schemes, Universal Links and APIs offered by target apps.

ReplayKit Screen Vision is subject to Apple's capture rules; iOS does not grant silent unrestricted cross-app screen control.

## AI endpoint

In Settings:

```text
Base URL: http://192.168.1.10:11434/v1
Model: gemma3:4b
Embedding model: embeddinggemma
API key: optional
```

The chat client first requests JSON action mode. If a local OpenAI-compatible server rejects `response_format`, Atlas automatically retries without that field.

## Security model

See `SECURITY.md`. Core principles:

- explicit OS permission before microphone/camera/screen capture;
- local AES-GCM encrypted memory;
- secure-storage encryption key;
- user-controlled app allow-list;
- no secret screen capture;
- Kill Switch;
- no logging of raw audio/frame/memory/API-key contents;
- production releases should use HTTPS rather than cleartext LAN development transport.
