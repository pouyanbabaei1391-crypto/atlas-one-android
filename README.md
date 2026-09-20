# Atlas One Mobile AI

A privacy-first Persian AI companion foundation for **Android + iPhone** with:

- Persian STT + TTS conversation
- configurable OpenAI-compatible LLM endpoint (`gemma3:4b` by default)
- encrypted long-term conversation memory + short-term context
- Camera Vision
- Screen Vision with explicit OS consent
- user-selected app launch/integration layer
- voice shutdown phrases and a global Kill Switch
- Android 13+ self-revocation request for camera/microphone permissions on shutdown
- iOS safe integration through documented URL/App-Intent style mechanisms rather than hidden UI control

## One-command Android build

Prerequisites: Flutter stable, Android SDK, Python 3, Java 17+.

Windows PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\BUILD_ANDROID.ps1
```

or double-click `BUILD_ANDROID.bat`.

Result:

```text
dist/Atlas-One-Android.apk
```

The APK can be sent by a messaging app or hosted on a website. Android still requires the recipient to approve installation from that source.

## iPhone build

An installable iOS build **must** be compiled and signed on a Mac with Xcode and an Apple Developer identity.

```bash
./BUILD_IOS.command
```

If signing is correctly configured, the result is:

```text
dist/Atlas-One-iOS.ipa
```

For ordinary users, distribute the iOS build through TestFlight/App Store. Ad Hoc IPA distribution requires registered devices.

## First launch

The home screen exposes separate user-controlled switches:

1. **Microphone** — requests microphone access and starts Persian speech recognition / synthesis.
2. **Screen Vision** — invokes the operating system screen-capture consent flow.
3. **Camera** — requests camera permission and enables visual questions.
4. **Autonomous Apps** — displays the applications/integrations that Atlas may use and lets the person opt in individually.
5. **Memory** — encrypted local persistent memory.

The red/power Kill Switch stops active capture/listening, camera use, screen sharing and selected app actions.

Voice shutdown examples include:

- `خاموش شو`
- `همه چیز رو خاموش کن`
- `خداحافظ اطلس`
- `دیگه گوش نده`

Atlas first says `خداحافظ <نام کاربر>` and then shuts down active capabilities.

## AI endpoint

Open **Settings** and enter an OpenAI-compatible base URL. Example for an Ollama-compatible service running on another machine on the same LAN:

```text
http://192.168.1.10:11434/v1
model: gemma3:4b
```

For production, use HTTPS and authenticated infrastructure. `android:usesCleartextTraffic="true"` is included only to make LAN development straightforward; remove it for a production internet release.

## Privacy architecture

Conversation bodies are encrypted with AES-GCM. The encryption key is stored through `flutter_secure_storage`, which maps to platform secure storage. Memory deletion is available in Settings.

Screen capture is never started silently. Android uses MediaProjection; the operating system displays its consent UI and a foreground notification while capture is active. iOS uses the system-approved screen-capture mechanism and does not bypass OS privacy controls.

## Critical platform reality: app control

Atlas intentionally does **not** ship a covert Accessibility-based click bot.

### Android

The project can enumerate launchable applications, let the person approve specific packages, and launch them. Deep links, Intents and official APIs can then be added per application. Autonomous AccessibilityService-driven planning/execution is unsuitable for a general-purpose Google Play assistant under current Play policy.

### iPhone

iOS does not permit a normal third-party app to enumerate and arbitrarily manipulate every installed application's UI. Production integrations need App Intents, Shortcuts, URL/universal links or APIs exposed by the target application. The included iOS bridge therefore exposes safe system integrations instead of pretending unrestricted UI control is possible.

## Production roadmap

For a commercial release, add:

- a signed HTTPS inference gateway and account system
- on-device model routing for offline operation
- streaming ASR/TTS provider adapters
- semantic embedding model packaged on-device
- app-specific connectors (banking actions should always require explicit confirmation)
- jailbreak/root detection and device integrity checks
- certificate pinning
- biometric lock for memory
- remote wipe for a user's own account
- crash reporting with sensitive-data redaction
- independent mobile security audit / penetration test

## Source layout

```text
lib/
  core/
    assistant_controller.dart
    ai_service.dart
    voice_service.dart
    memory_service.dart
    camera_service.dart
    native_bridge.dart
    app_action_service.dart
  screens/
    home_screen.dart
    settings_screen.dart
native/
  android/   # MediaProjection + package launcher + permission shutdown bridge
  ios/       # ReplayKit-compatible capture + safe system integrations
build.py     # creates the Flutter platform scaffold and builds release artifacts
```

This is a buildable engineering foundation, not a claim that Android/iOS allow unrestricted hidden control of every app.
