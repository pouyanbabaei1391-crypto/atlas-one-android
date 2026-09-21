# Voice and vision incremental update

## Scope
All original archive entries are retained. No updater scripts, repository URL,
native bridges, API endpoints, model settings, memory implementation, app integrations,
build.py, dependency declarations, or native permission files were modified.

The supplied home screen already contained no decorative header images, English
feature labels, or camera preview. Those properties remain intact.

## Improvements
- Speech starts from complete word groups after a 220 ms chunk wait, or from
  the first sentence/36-character group, instead of waiting for 100 characters.
  This wait is a text buffering setting, not total response latency.
- Added a Persian stop-response / listen-again button. This is tap interruption;
  simultaneous automatic voice interruption is not implemented.
- Speech cancellation releases the pending speech future and cancels buffered text.
- Recognition initialization can retry after failure; older permission requests
  cannot reactivate a microphone that the user has switched off.
- Slightly increased device TTS speed. Naturalness depends on the installed
  Persian voice; this update does not install a neural voice or a cloud service.
- Camera frame requests are serialized and camera shutdown waits for capture.
  Front/back camera selection and invisible preview remain available.
- Screen capture readiness and manual capture failures have Persian feedback.
- Visual instructions explicitly reject unreadable text and distinguish sources.
- Added the two missing GitHub workflow files required by the unchanged updater.
  Android runs dependency resolution, analysis, tests, the existing builder,
  and uploads its APK. iOS validation is manual and unsigned.

## Device requirements and limits
A reachable vision-capable model server and Persian recognition/TTS are required.
Less than one second end-to-end is NOT guaranteed or measured here.
Android screen capture still needs system approval; choose the entire display
if the OS offers app-only versus full-screen capture. Protected screens may be blank.
The existing iOS implementation captures the app; whole-device sharing outside
the app requires a Broadcast Upload Extension, which was not added because native
system connections are outside the requested modification scope.
Vision uses snapshots at request time and periodic analysis while the microphone
is off, not continuous video reasoning. No camera preview is mounted.
Turning on the camera or screen starts a short spoken analysis when idle.

## Validation
VERIFY_PROJECT.py passes. Original-entry byte comparison confirms that updater,
repository URL, and native/system files are unchanged. No original file was deleted.
Flutter/Dart SDKs and a mobile device are unavailable in this execution environment.
Flutter tests were added but NOT run locally. APK compilation and hardware
voice/camera/screen behavior must pass the included CI and real-device checks.
The ZIP is source code, not an Android installer. Run UPDATE_TO_GITHUB.bat
on the extracted project, then retrieve the APK artifact from GitHub Actions.

## On-device acceptance checks
1. Enable microphone, allow permission, speak Persian; hear a Persian answer.
2. Interrupt an answer using the new button, then speak a second request.
3. Disable microphone during permission initialization; it must stay disabled.
4. Enable camera, allow permission; hear a description without a preview.
5. Switch lens and ask about a visible object; verify grounded observations.
6. Enable Android full-display sharing, open another app, ask about its text.
7. Stop sharing from the system notification; verify no new frames are available.
8. Run the existing updater and verify a successful Actions APK artifact.
