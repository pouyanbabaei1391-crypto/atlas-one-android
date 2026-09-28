# Atlas One Privacy Policy

Effective date: 28 September 2026

Atlas One is an on-device mobile assistant. This policy must be published at a public HTTPS URL and updated with the developer's legal name, support email, jurisdiction, retention terms, and any production server actually configured before public release.

## Data processed

- Microphone audio is accessed only after the user grants permission and starts voice mode. Android's speech provider may process audio according to that provider's settings.
- Camera frames are accessed only while Camera Vision is enabled and are analyzed on the device by the configured YOLO model unless the user explicitly configures a remote service.
- Screen content is accessed only after Android displays and the user accepts the MediaProjection consent dialog.
- Conversation memory, preferences, and model state are stored locally. Conversation content is encrypted at rest when memory is enabled.
- The app may list launchable applications and open an application only in response to an explicit user action. It does not request the broad QUERY_ALL_PACKAGES permission.

## Network use

The app uses HTTPS to download the selected local language model and may contact a user-configured AI gateway. Cleartext HTTP is disabled in the secure release. No advertising or analytics SDK is included in this source package.

## Sharing and sale

The developer does not sell personal information. Data is not shared with advertisers. A system speech provider, model host, or explicitly configured AI provider may receive data needed to perform the feature selected by the user and is governed by its own policy.

## Retention and deletion

Local data remains on the device until the user clears memory, revokes access, clears app storage, or uninstalls the app. Sensitive app data is excluded from Android cloud backup and device transfer in the secure release.

## Security

The secure release uses Android protected storage, AES-256-GCM for conversation memory, HTTPS-only transport, model SHA-256 verification, least-privilege exported components, and signed release artifacts. No security control can eliminate all risk.

## User controls

Users can disable microphone, camera, screen capture, and memory; stop active sessions; revoke permissions in Android Settings; clear stored memory; and uninstall the app.

## Children

The app is not directed to children under the applicable minimum digital-consent age unless the developer completes the required child-safety design and store declarations.

## Contact

Before publication, replace this section with the developer's verified legal name and support email.

