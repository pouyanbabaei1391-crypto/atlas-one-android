ATLAS VOICE 2 - ANDROID BACKGROUND VOICE FIX

INSTALL THE NEW BUILD
1. Extract the complete ZIP.
2. Run the unchanged UPDATE_TO_GITHUB.bat from the General Gemma34b folder.
3. Complete GitHub authentication if asked. Wait for Build Atlas Android APK to succeed in Actions.
4. Download Atlas-One-Android-APK, extract it, and install the new APK. Uploading source alone does NOT update the app already installed on your phone.
5. Confirm that the app header says Atlas Voice 2 (version 0.5.0+5).

VOICE CHECKS
Tap Test speaker: a local English sentence plays without an AI server.
Tap Start voice chat while the app is open, allow microphone access, and allow notifications when requested. You should hear: I am ready. Go ahead.
Speak normally. The input level bar shows recognizer microphone activity; live text shows the hypothesis. The foreground notification stays visible during the session.
Tap Test AI connection if transcription works but replies do not. The original default server address is http://192.168.1.10:11434/v1; it is an example/default, not a hosted AI service. Settings must point to YOUR running, reachable server and installed model. Phone localhost is not your laptop. The server address and model are not overwritten by this update.

WHAT CHANGED
- Added Android RecognitionService and TTS_SERVICE package visibility queries.
- Added a microphone foreground service and permission declaration.
- Added a process-owned Flutter engine so closing the Activity does not destroy the chat controller.
- Added native Android speech recognition with partial/final results, real input-level events, stale callback rejection, timeouts and controlled retries.
- Prefer on-device recognition when available; fall back to the system provider if its English model is unavailable.
- Added native English TTS initialization, installed local voice selection, explicit failures, completion and cancellation handling.
- STT no longer depends on successful TTS initialization.
- Temporary no-speech/network/busy failures restart recognition; fatal missing-service/language/permission errors explain the actual problem.
- Added independent speaker and AI-connection diagnostics.
- Existing camera, screen, selected-app, memory and AI request paths remain in the controller.
- The notification has Stop voice chat. End voice chat also cancels pending output and releases the service and wake lock.

BACKGROUND BEHAVIOR AND LIMITS
Start the session while the Activity is visible. The service is designed to continue after Home/Back, screen lock, and task dismissal while Android keeps the process alive. Some manufacturers impose additional battery restrictions. Force stop, process death, revoked permissions, reboot or system termination stops the session; it never silently restarts after these events. Reopen Atlas and explicitly start it again.
Recognition is turn-based and automatically rearmed after each response. It pauses during assistant playback to avoid transcribing its own voice. Interrupt and speak cancels a response. This is not simultaneous full-duplex listening during playback. OS speech providers may impose session boundaries and may ignore requested silence durations. English recognition/voice data and a reachable AI server are still required.
Background voice is implemented for Android. iOS retains its previous foreground voice behavior.

PRESERVATION
All 42 original uploaded files are byte-identical, including original Dart UI, native sources, build.py, UPDATE_TO_GITHUB.bat/.ps1 and repository URL. Updated code lives only in the additive overlay and disposable build staging. The previous overlay is archived under english_voice_addon/history. The existing original BUILD_ANDROID scripts still build the original edition. For a local build of THIS edition, use BUILD_ENGLISH_VOICE_ANDROID.bat.

VALIDATION
Passed: all original hashes; parsing of 22 Dart/Kotlin files; Android manifest XML/service permissions/queries; workflow YAML; Python build entry; isolated staging preparation and VERIFY_PROJECT.py.
Five added mocked native-channel regression tests cover transcripts/cancellation, retryable vs fatal errors, native stop, TTS retry and stopping during initialization. Existing streaming tests remain included. The build runs Flutter analysis and tests before compiling the APK.
Local Flutter executable tests and Android compilation were NOT completed. Automatic approval review rejected continuing the tool process because it reported an attempted cloud-instance metadata endpoint access, which can expose credentials and was not authorized. The blocked operation was not retried or bypassed. No physical-device microphone, audio or background longevity test was available. No sub-second latency claim is made.

OFFICIAL IMPLEMENTATION REFERENCES
https://developer.android.com/reference/android/speech/SpeechRecognizer
https://developer.android.com/reference/android/speech/tts/TextToSpeech
https://developer.android.com/develop/background-work/services/fgs/service-types
https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
https://api.flutter.dev/javadoc/io/flutter/embedding/android/FlutterActivity.html
