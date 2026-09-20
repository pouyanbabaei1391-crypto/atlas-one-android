# Atlas One Security Invariants

1. No microphone, camera or screen capture before explicit OS/user permission.
2. No silent screen capture.
3. No arbitrary third-party app UI control through hidden accessibility abuse.
4. Sensitive external actions require explicit user confirmation in production connectors.
5. Long-term conversation content is encrypted at rest.
6. Kill Switch terminates active capture/listening and disables the app-action allowlist.
7. Android 13+ may request self-revocation of runtime camera/microphone permissions when the Kill Switch uses OS-revocation mode.
8. iOS permissions remain controlled by the user in Settings; the app stops access immediately but cannot secretly rewrite the user's privacy choices.
9. Production traffic must use HTTPS; development cleartext LAN transport is not production-safe.
10. Never log raw microphone audio, frames, prompts, tokens, memory plaintext or API keys.
