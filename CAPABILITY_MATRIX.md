# Capability Matrix

| Capability | Android | iOS |
|---|---|---|
| Persian STT/TTS | Yes, device speech/TTS services | Yes, device speech/TTS services |
| Screen Vision | MediaProjection + explicit system consent | ReplayKit subject to Apple capture rules |
| Camera Vision | Yes | Yes |
| Encrypted long-term memory | Yes | Yes |
| Short-term context | Yes | Yes |
| Save conversations | Yes when Memory is enabled (default ON) | Same |
| Show installed/launchable apps | Yes, launchable apps visible to package manager | No unrestricted enumeration; safe integrations only |
| AI opens user-approved app | Yes | Only documented URL/App integrations |
| Arbitrary hidden control of every app UI | No | No |
| Voice shutdown + goodbye name | Yes | Yes |
| Stop all Atlas active sessions | Yes | Yes |
| Programmatically revoke Camera/Mic permission | Android 13+ self-revocation request | iOS does not expose this to third-party apps |
| Direct messenger install | APK with Android user approval | Not general-purpose; Apple signing/distribution required |
