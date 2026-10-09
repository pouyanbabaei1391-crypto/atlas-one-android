# Preserve user data across APK updates

Android permits an update to keep existing app data only when the **applicationId stays the same** and the new APK is signed by the **same certificate**. In the existing automated GitHub workflow, each debug runner may generate a new debug keystore, so users must NOT assume a downloaded APK will update the old app in place.

To prepare a real release, generate and store a signing keystore securely offline, establish a consistent signing process using **GitHub encrypted repository secrets** or a secure local CI environment, and sign all future releases with the same key. Never add passwords or unencrypted private signing keys to the public repo.

Until release signing is configured, do not uninstall the previous app if you need its private downloaded model. Where possible, save a verified model GGUF yourself into a user-accessible location and use the app's **Import GGUF** feature. Android sandbox isolation prevents reading another application's private model directory.

The ZIP includes source and debug workflow, NOT an end-to-end tested signed release APK.
