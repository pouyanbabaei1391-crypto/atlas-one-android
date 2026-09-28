#!/usr/bin/env python3
"""Build the original project through an additive, fail-closed security layer."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STAGE = ROOT / ".build/english_voice_source"


def run(command: list[str], cwd: Path | None = None) -> None:
    print(">", " ".join(command), flush=True)
    subprocess.run(command, cwd=cwd, check=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Secure Atlas Android release builder")
    parser.add_argument("target", nargs="?", default="android", choices=["android"])
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()

    run([sys.executable, "english_voice_addon/build.py", "--prepare-only"], ROOT)

    sys.path.insert(0, str(ROOT / "security_addon"))
    from security_build_hook import harden_stage

    harden_stage(STAGE)
    shutil.copy2(
        ROOT / "security_addon/security_build_hook.py",
        STAGE / "security_build_hook.py",
    )

    builder = STAGE / "build.py"
    text = builder.read_text(encoding="utf-8")
    anchor = "    configure(work)"
    if text.count(anchor) != 1:
        raise RuntimeError("Secure Android configuration anchor mismatch")
    text = text.replace(
        anchor,
        anchor
        + "\n    from security_build_hook import configure_release_signing"
        + "\n    configure_release_signing(work)",
        1,
    )
    builder.write_text(text, encoding="utf-8")

    if args.prepare_only:
        print(f"SECURE BUILD STAGE: {STAGE}", flush=True)
        return

    if os.environ.get("ATLAS_BUNDLE_MODEL", "false").lower() == "true":
        sys.path.insert(0, str(ROOT / "english_voice_addon"))
        from local_build import bundle_model

        bundle_model(STAGE / "native/android/app/src/main/assets/gemma")

    run(["flutter", "pub", "get"], STAGE)
    run(
        [
            "flutter",
            "analyze",
            "--no-fatal-infos",
            "--no-fatal-warnings",
            "lib",
            "test",
        ],
        STAGE,
    )
    run(["flutter", "test"], STAGE)
    run([sys.executable, "build.py", "android"], STAGE)

    generated = STAGE / ".build/atlas_one_android"
    run(
        [
            "flutter",
            "build",
            "appbundle",
            "--release",
            "--target-platform",
            "android-arm64",
        ],
        generated,
    )

    output = ROOT / "dist"
    output.mkdir(parents=True, exist_ok=True)
    apk_source = STAGE / "dist/Atlas-One-Android.apk"
    aab_source = generated / "build/app/outputs/bundle/release/app-release.aab"
    apk = output / "Atlas-One-Secure-Release.apk"
    aab = output / "Atlas-One-Google-Play.aab"
    shutil.copy2(apk_source, apk)
    shutil.copy2(aab_source, aab)
    (output / "SHA256SUMS.txt").write_text(
        f"{sha256(apk)}  {apk.name}\n{sha256(aab)}  {aab.name}\n",
        encoding="utf-8",
    )
    print(f"SIGNED APK: {apk}", flush=True)
    print(f"SIGNED PLAY BUNDLE: {aab}", flush=True)


if __name__ == "__main__":
    main()
