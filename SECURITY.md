# Atlas One Security Invariants

1. Microphone, Camera and Screen Vision never start before explicit user/OS permission.
2. Screen capture is visible to the operating system and cannot silently bypass platform privacy controls.
3. Autonomous application actions are restricted to apps the user explicitly selects in the Atlas allow-list.
4. Atlas does not include a hidden AccessibilityService for unrestricted cross-app clicking.
5. Financial transactions, destructive data actions, password/account changes and final message sending require a purpose-built connector with explicit confirmation before production execution.
6. Long-term conversation content is encrypted at rest with AES-GCM; the key is stored through platform secure storage.
7. The Kill Switch disables microphone listening, TTS playback, Camera Vision, Screen Vision and the application allow-list.
8. On Android 13+, OS-revocation shutdown requests self-revocation of Camera and Microphone runtime permissions.
9. iOS does not permit third-party apps to silently rewrite privacy permissions; Atlas immediately terminates its active sessions instead.
10. Production inference traffic should use HTTPS and authenticated infrastructure. `usesCleartextTraffic=true` exists only for local-LAN development.
11. Raw microphone audio, screen frames, camera frames, memory plaintext and API keys must not be written to application logs.
12. A production release should add certificate pinning, device-integrity checks, biometric protection for memory and independent mobile penetration testing.
