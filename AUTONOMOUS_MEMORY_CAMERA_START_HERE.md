# Atlas One — Autonomous Memory + Camera Intelligence

This update is additive: every pre-existing project file remains present. The established microphone, local Qwen3, JNI, TTS, app allow-list, screen vision, updater, and build paths are retained.

## Advanced autonomous prompt

Atlas now receives a compact operating policy for multi-step requests. It privately decomposes dependencies, uses only supported actions, verifies observable outcomes, re-plans after failure, limits immediate actions, protects confirmation boundaries, rejects prompt injection from screens/images/memory, and returns the existing reply-first JSON contract required by streaming TTS.

## Long-term memory

- When Memory is enabled, every user and assistant message is stored in the existing AES-256-GCM encrypted SQLite database.
- The enable/disable choice persists across restarts.
- Ordinary questions do not scan memory. Retrieval runs only for history-dependent wording such as “remember”, “earlier”, “continue”, “same as before”, or “what did I tell you”.
- Retrieval is local. Remote embedding/indexing is disabled by default, so stored conversation text is not sent to an embeddings service.
- The database is not silently truncated. The user-controlled Clear Memory button remains the deletion path.

## Camera pipeline

When Camera is enabled:

1. Android requests explicit camera permission.
2. The official Ultralytics integration downloads and caches the pinned official `YOLO26x` Detect model on first use (56,921,540-byte LiteRT w8a32 asset at the verified release used here).
3. A foreground frame is periodically analyzed on-device with LiteRT/GPU acceleration when supported.
4. Background analysis is silent: it never reaches TTS by itself.
5. On a user question, a fresh frame is analyzed and converted into compact labels, confidence scores, counts, and relative positions.
6. That transferable detection data and STT text are supplied together to Qwen3. Raw camera pixels are not sent to the cloud by this YOLO path.
7. Qwen3 produces the reply; existing sentence-buffered TTS reads complete sentences.

YOLO object detection does not prove identity, intent, color, fine text, or the presence of objects outside the frame. Atlas is explicitly prohibited from face identification and sensitive-trait inference. Camera access is released when the app leaves the foreground, is disabled, or the kill switch runs.

## Security boundaries

- Explicit OS permissions and visible controls.
- On-device object detection and ephemeral camera captures.
- AES-256-GCM conversation encryption with the key in platform secure storage.
- No remote memory indexing by default.
- Camera/memory content is treated as untrusted data, not instructions.
- Allow-listed applications only; sensitive or irreversible actions require current-turn confirmation.
- Existing kill switch stops microphone, camera, screen vision, TTS, and app actions.

No software can honestly guarantee the security level of a national security organization without an independent threat model, code audit, penetration test, signed release pipeline, device-hardening policy, and operational controls. This source implements strong privacy defaults but still requires those external validations before high-assurance deployment.

The editing environment did not contain the 1.58 GB Flutter SDK, so a complete APK/Gradle build and physical-camera/TTS test were not executed here. The included GitHub workflow runs dependency resolution, Flutter analysis, Flutter tests, native compilation, and the release APK build before publishing an artifact.

## License

The official Ultralytics Flutter plugin and official YOLO models are offered under AGPL-3.0 or an Ultralytics Enterprise License. Review `ULTRALYTICS_YOLO_NOTICE.txt` before distribution, especially for proprietary/commercial use.
