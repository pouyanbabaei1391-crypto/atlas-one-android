# Atlas One V6 GitHub build fix

Root cause found in the actual SLIM staging path: `english_voice_addon/build.py` overlays `english_voice_addon/overlay` after copying the root source. V5 added the Live Agent APIs to root `lib/core/app_action_service.dart` and `native_bridge.dart`, but the older overlay versions replaced those files during CI staging. The staged agent code then referenced methods that did not exist in the staged core API, causing `flutter analyze` to fail and GitHub Actions to exit with code 1 before an APK artifact was produced.

Fixes:
- Synchronized the Live Accessibility API into the SLIM/Qwen overlay.
- Merged LivePhoneAgent + ExecutionEngine into the overlay AssistantController while preserving its local Qwen3/cloud-fallback/voice logic.
- Added fast lexical memory retrieval to the overlay MemoryService and only invokes recall for past-context queries.
- Fixed the Dart RegExp portability issue in live_phone_agent.dart.
- Hid Camera and Screen Vision cards in the actual overlay UI used by CI, without deleting their legacy source.
- Verified `english_voice_addon/build.py android --prepare-only` produces a staged source containing the Live Agent APIs, integration and lexical memory.
- Python build scripts compile with `py_compile`.

GitHub/update integrity:
`.github/workflows/build-android-apk.yml`, `UPDATE_TO_GITHUB.bat`, `UPDATE_TO_GITHUB.ps1`, `UPLOAD_TO_GITHUB.bat`, and `.atlas_repo_url` were SHA-256 checked before/after and were not modified.

The environment used to prepare this ZIP does not include Flutter/Android SDK, so the final release APK itself could not be compiled locally here. GitHub Actions remains the intended APK compiler.
