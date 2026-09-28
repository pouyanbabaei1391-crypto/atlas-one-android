"""Add security controls only to the disposable build stage.

The shipped source tree remains byte-for-byte intact. Every replacement is
guarded so an upstream change fails the build instead of silently weakening it.
"""

from __future__ import annotations

import os
from pathlib import Path


def _replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"Security integration anchor mismatch in {path}: expected 1, found {count}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def harden_stage(stage: Path) -> None:
    """Harden copied Dart/Android sources before analysis and compilation."""
    main = stage / "lib/main.dart"
    manifest = stage / "native/android/app/src/main/AndroidManifest.xml"
    if not main.is_file() or not manifest.is_file():
        raise RuntimeError("Security hardening requires the complete Android build stage")

    _replace_once(
        main,
        "  await controller.init();",
        "  try {\n"
        "    await controller.init();\n"
        "  } catch (error, stack) {\n"
        "    // Never strand the user on the launch screen because an optional\n"
        "    // service or restored encrypted record could not be initialized.\n"
        "    debugPrint('Safe startup recovery: $error\\n$stack');\n"
        "    controller.status =\n"
        "        'Safe mode: initialization was recovered. Open Settings to retry.';\n"
        "  }",
    )

    _replace_once(
        manifest,
        '        android:usesCleartextTraffic="true">',
        '        android:usesCleartextTraffic="false"\n'
        '        android:allowBackup="false"\n'
        '        android:fullBackupContent="false"\n'
        '        android:dataExtractionRules="@xml/data_extraction_rules"\n'
        '        android:networkSecurityConfig="@xml/network_security_config">',
    )

    xml = stage / "native/android/app/src/main/res/xml"
    xml.mkdir(parents=True, exist_ok=True)
    (xml / "network_security_config.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
""",
        encoding="utf-8",
    )
    (xml / "data_extraction_rules.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup disableIfNoEncryptionCapabilities="true">
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
    </device-transfer>
</data-extraction-rules>
""",
        encoding="utf-8",
    )
    (stage / "SECURITY_HARDENING_INTEGRATED.txt").write_text(
        "Security controls were applied only to this disposable build stage.\n",
        encoding="utf-8",
    )


def configure_release_signing(work: Path) -> None:
    """Require a stable private release/upload key without embedding secrets."""
    names = (
        "ATLAS_KEYSTORE_PATH",
        "ATLAS_KEY_ALIAS",
        "ATLAS_STORE_PASSWORD",
        "ATLAS_KEY_PASSWORD",
    )
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise RuntimeError(
            "Release signing is required. Missing environment variables: "
            + ", ".join(missing)
        )
    keystore = Path(os.environ["ATLAS_KEYSTORE_PATH"])
    if not keystore.is_file() or keystore.stat().st_size == 0:
        raise RuntimeError("ATLAS_KEYSTORE_PATH does not point to a valid keystore")

    gradle = work / "android/app/build.gradle.kts"
    if not gradle.is_file():
        raise RuntimeError("Secure release signing expects Flutter Kotlin Gradle templates")

    _replace_once(
        gradle,
        "    buildTypes {",
        "    signingConfigs {\n"
        "        create(\"release\") {\n"
        "            storeFile = file(System.getenv(\"ATLAS_KEYSTORE_PATH\"))\n"
        "            storePassword = System.getenv(\"ATLAS_STORE_PASSWORD\")\n"
        "            keyAlias = System.getenv(\"ATLAS_KEY_ALIAS\")\n"
        "            keyPassword = System.getenv(\"ATLAS_KEY_PASSWORD\")\n"
        "        }\n"
        "    }\n\n"
        "    buildTypes {",
    )
    _replace_once(
        gradle,
        '            signingConfig = signingConfigs.getByName("debug")',
        '            signingConfig = signingConfigs.getByName("release")\n'
        "            isDebuggable = false",
    )
