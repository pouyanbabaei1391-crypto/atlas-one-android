# English Voice Update

The main screen is voice-only. Tap Start voice chat, grant microphone/speech permissions, and speak in English. Atlas listens again after speaking. Use Interrupt and speak to stop the current answer, or End voice chat to stop the microphone and voice playback.

All application labels, status messages, native permission descriptions, and screen-sharing notifications are English. Existing conversation records are preserved in their original language. New assistant responses are instructed to use natural English.

The original message composer is retained as an unmounted method. Every changed file has a byte-identical original in original_source_before_english_voice. No original archive entries or connection/update scripts were removed.

## Latency changes

English speech output initializes in the background at startup. Speech recognition requests a 500 ms pause and a 200 ms final-result timeout; actual end-of-speech timing remains controlled by the operating system. Streamed complete words flush after 140 ms instead of 220 ms. Semantic recall waits at most 40 ms in voice mode instead of 150 ms; conversation history remains available and memory indexing continues. The model is instructed to emit its reply first and begin with a concise useful sentence.

These are latency optimizations, not a measured sub-second guarantee. Recognition, network, model loading/inference, and installed English voices determine actual response time. Speech recognition may require internet access. An English system voice must be installed.

## Validation

Archive checks confirm every original file is present, every changed file has an exact original backup, and all existing GitHub/update/build connection files are byte-identical. The rendered main-screen build code contains no text composer. Flutter and Dart are unavailable in the editing environment, so compilation, widget tests, and device audio were NOT run.

Added test/english_voice_stream_test.dart covers early English output, action isolation, and cancellation. Run flutter test in a configured Flutter environment, followed by a device test: allow speech, ask a question, hear the answer, interrupt, ask again, and end voice chat. Check permission denial and missing English voices as well.

The supplied archive already lacks .github/workflows and contains only empty .git directories. These omissions were preserved rather than replacing your connection setup. Apply this update in your existing project directory and retain your existing GitHub files. Use the existing build/update process. This ZIP is project source, not an APK installer.
