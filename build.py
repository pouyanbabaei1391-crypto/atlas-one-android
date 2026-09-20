#!/usr/bin/env python3
"""Reproducible Atlas One mobile builder.

Android: builds a shareable release APK.
iOS: validates/builds on macOS. A directly installable IPA still requires Apple signing.
"""
from __future__ import annotations

import argparse
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORK_ROOT = ROOT / ".build"
DIST = ROOT / "dist"


def run(cmd: list[str], cwd: Path | None = None, env: dict | None = None) -> None:
    print(">", " ".join(map(str, cmd)), flush=True)
    merged = os.environ.copy()
    if env:
        merged.update(env)
    subprocess.run(cmd, cwd=str(cwd) if cwd else None, env=merged, check=True)


def require(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise SystemExit(f"Required tool not found in PATH: {name}")
    return path


def copytree_contents(src: Path, dst: Path) -> None:
    if not src.exists():
        raise SystemExit(f"Missing source directory: {src}")
    for item in src.iterdir():
        target = dst / item.name
        if item.is_dir():
            shutil.copytree(item, target, dirs_exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def replace_required(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count == 0:
        raise SystemExit(f"Unable to patch generated Android Gradle field: {label}")
    return updated


def prepare_base(platform: str) -> Path:
    require("flutter")
    work = WORK_ROOT / f"atlas_one_{platform}"
    if work.exists():
        shutil.rmtree(work)
    work.parent.mkdir(parents=True, exist_ok=True)

    run([
        "flutter", "create",
        f"--platforms={platform}",
        "--org", "com.atlas",
        "--project-name", "atlas_one",
        str(work),
    ])

    shutil.copy2(ROOT / "pubspec.yaml", work / "pubspec.yaml")
    shutil.copy2(ROOT / "analysis_options.yaml", work / "analysis_options.yaml")
    shutil.rmtree(work / "lib", ignore_errors=True)
    shutil.copytree(ROOT / "lib", work / "lib")
    return work


def patch_android(work: Path) -> None:
    android = work / "android"
    app = android / "app"

    # Remove Flutter's stock MainActivity, then install Atlas' native bridge.
    for file in app.rglob("MainActivity.kt"):
        file.unlink()
    for file in app.rglob("MainActivity.java"):
        file.unlink()
    copytree_contents(ROOT / "native" / "android", android)

    kts = app / "build.gradle.kts"
    groovy = app / "build.gradle"
    if kts.exists():
        text = kts.read_text(encoding="utf-8")
        text = replace_required(text, r'namespace\s*=\s*"[^"]+"', 'namespace = "com.atlas.one"', "namespace")
        text = replace_required(text, r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.atlas.one"', "applicationId")
        # Camera and current mobile plugins require a modern Android floor. Keep
        # compile/target SDK at the value emitted by the installed Flutter SDK.
        text = replace_required(text, r'minSdk\s*=\s*[^\n]+', 'minSdk = 24', "minSdk")
        kts.write_text(text, encoding="utf-8")
    elif groovy.exists():
        text = groovy.read_text(encoding="utf-8")
        text = replace_required(text, r'namespace\s+["\'][^"\']+["\']', 'namespace "com.atlas.one"', "namespace")
        text = replace_required(text, r'applicationId\s+["\'][^"\']+["\']', 'applicationId "com.atlas.one"', "applicationId")
        text = replace_required(text, r'minSdk(?:Version)?\s+[^\n]+', 'minSdk 24', "minSdk")
        groovy.write_text(text, encoding="utf-8")
    else:
        raise SystemExit("Flutter did not generate android/app/build.gradle(.kts)")


def patch_ios(work: Path) -> None:
    runner = work / "ios" / "Runner"
    shutil.copy2(ROOT / "native" / "ios" / "Runner" / "AppDelegate.swift", runner / "AppDelegate.swift")

    info = runner / "Info.plist"
    with info.open("rb") as file:
        data = plistlib.load(file)

    data["NSCameraUsageDescription"] = "Atlas only accesses the camera after your explicit permission for Camera Vision."
    data["NSMicrophoneUsageDescription"] = "Atlas only accesses the microphone after your explicit permission for Persian voice conversation."
    data["NSSpeechRecognitionUsageDescription"] = "Atlas uses speech recognition to convert Persian speech to text."
    data["NSLocalNetworkUsageDescription"] = "Atlas can connect to an AI model on your local network when you choose that configuration."
    ats = data.setdefault("NSAppTransportSecurity", {})
    ats["NSAllowsLocalNetworking"] = True

    with info.open("wb") as file:
        plistlib.dump(data, file)


def prepare_android() -> Path:
    work = prepare_base("android")
    patch_android(work)
    run(["flutter", "pub", "get"], cwd=work)
    return work


def prepare_ios() -> Path:
    if sys.platform != "darwin":
        raise SystemExit("iOS builds require macOS + Xcode.")
    require("xcodebuild")
    work = prepare_base("ios")
    patch_ios(work)
    run(["flutter", "pub", "get"], cwd=work)
    return work


def build_android() -> None:
    work = prepare_android()
    run(["flutter", "build", "apk", "--release"], cwd=work)

    src = work / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not src.is_file() or src.stat().st_size == 0:
        raise SystemExit(f"APK not produced: {src}")

    DIST.mkdir(parents=True, exist_ok=True)
    dst = DIST / "Atlas-One-Android.apk"
    shutil.copy2(src, dst)
    print(f"ANDROID APK: {dst}", flush=True)


def build_ios_unsigned() -> None:
    work = prepare_ios()
    run(["flutter", "build", "ios", "--release", "--no-codesign"], cwd=work)
    app = work / "build" / "ios" / "iphoneos" / "Runner.app"
    if not app.is_dir():
        raise SystemExit("Unsigned Runner.app was not produced.")
    DIST.mkdir(parents=True, exist_ok=True)
    archive = shutil.make_archive(str(DIST / "Atlas-One-iOS-UNSIGNED"), "zip", root_dir=app.parent, base_dir=app.name)
    print(f"iOS unsigned validation artifact: {archive}", flush=True)


def build_ios_signed() -> None:
    work = prepare_ios()
    # Xcode project must already resolve to a valid Apple Team/profile.
    run(["flutter", "build", "ipa", "--release"], cwd=work)
    ipa_dir = work / "build" / "ios" / "ipa"
    candidates = list(ipa_dir.glob("*.ipa"))
    if not candidates:
        raise SystemExit("No signed IPA was produced. Configure Apple signing/provisioning and rerun.")
    DIST.mkdir(parents=True, exist_ok=True)
    dst = DIST / "Atlas-One-iOS.ipa"
    shutil.copy2(candidates[0], dst)
    print(f"SIGNED iOS IPA: {dst}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Atlas One mobile application")
    parser.add_argument(
        "target",
        choices=["android", "ios-unsigned", "ios-signed"],
        nargs="?",
        default="android",
    )
    args = parser.parse_args()

    if args.target == "android":
        build_android()
    elif args.target == "ios-unsigned":
        build_ios_unsigned()
    else:
        build_ios_signed()


if __name__ == "__main__":
    main()
