#!/usr/bin/env python3
import argparse
import os
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORK = ROOT / '.build' / 'atlas_one'
DIST = ROOT / 'dist'


def run(cmd, cwd=None):
    print('>', ' '.join(map(str, cmd)))
    subprocess.run(cmd, cwd=cwd, check=True)


def require(name):
    p = shutil.which(name)
    if not p:
        raise SystemExit(f'{name} was not found in PATH. Install Flutter first: https://docs.flutter.dev/get-started/install')
    return p


def copytree_contents(src: Path, dst: Path):
    for item in src.iterdir():
        target = dst / item.name
        if item.is_dir():
            shutil.copytree(item, target, dirs_exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def patch_android():
    app = WORK / 'android' / 'app'
    # Remove generated MainActivity so only the Atlas native bridge is compiled.
    for f in app.rglob('MainActivity.kt'):
        f.unlink()
    copytree_contents(ROOT / 'native' / 'android', WORK / 'android')

    kts = app / 'build.gradle.kts'
    groovy = app / 'build.gradle'
    if kts.exists():
        text = kts.read_text()
        text = re.sub(r'namespace\s*=\s*"[^"]+"', 'namespace = "com.atlas.one"', text)
        text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.atlas.one"', text)
        kts.write_text(text)
    elif groovy.exists():
        text = groovy.read_text()
        text = re.sub(r'namespace\s+["\'][^"\']+["\']', 'namespace "com.atlas.one"', text)
        text = re.sub(r'applicationId\s+["\'][^"\']+["\']', 'applicationId "com.atlas.one"', text)
        groovy.write_text(text)


def patch_ios():
    shutil.copy2(ROOT / 'native' / 'ios' / 'Runner' / 'AppDelegate.swift', WORK / 'ios' / 'Runner' / 'AppDelegate.swift')
    info = WORK / 'ios' / 'Runner' / 'Info.plist'
    with info.open('rb') as f:
        data = plistlib.load(f)
    data['NSCameraUsageDescription'] = 'Atlas only accesses the camera after your explicit permission for Camera Vision.'
    data['NSMicrophoneUsageDescription'] = 'Atlas only accesses the microphone after your explicit permission for Persian voice conversation.'
    data['NSSpeechRecognitionUsageDescription'] = 'Atlas uses speech recognition to convert your Persian speech to text.'
    data['NSLocalNetworkUsageDescription'] = 'Atlas can connect to an AI model on your local network when you choose that configuration.'
    ats = data.setdefault('NSAppTransportSecurity', {})
    ats['NSAllowsLocalNetworking'] = True
    with info.open('wb') as f:
        plistlib.dump(data, f)


def prepare():
    require('flutter')
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.parent.mkdir(parents=True, exist_ok=True)
    run(['flutter', 'create', '--platforms=android,ios', '--org', 'com.atlas', '--project-name', 'atlas_one', str(WORK)])
    shutil.copy2(ROOT / 'pubspec.yaml', WORK / 'pubspec.yaml')
    shutil.copy2(ROOT / 'analysis_options.yaml', WORK / 'analysis_options.yaml')
    shutil.rmtree(WORK / 'lib', ignore_errors=True)
    shutil.copytree(ROOT / 'lib', WORK / 'lib')
    patch_android()
    patch_ios()
    run(['flutter', 'pub', 'get'], cwd=WORK)


def build_android():
    run(['flutter', 'build', 'apk', '--release'], cwd=WORK)
    DIST.mkdir(exist_ok=True)
    src = WORK / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-release.apk'
    dst = DIST / 'Atlas-One-Android.apk'
    shutil.copy2(src, dst)
    print(f'ANDROID APK: {dst}')


def build_ios():
    if sys.platform != 'darwin':
        raise SystemExit('An installable iOS IPA must be built and signed on macOS with Xcode and an Apple Developer signing identity.')
    run(['flutter', 'build', 'ipa', '--release'], cwd=WORK)
    ipa_dir = WORK / 'build' / 'ios' / 'ipa'
    files = list(ipa_dir.glob('*.ipa'))
    if not files:
        raise SystemExit('Xcode/Flutter did not produce an IPA. Configure Signing & Capabilities, then rerun.')
    DIST.mkdir(exist_ok=True)
    dst = DIST / 'Atlas-One-iOS.ipa'
    shutil.copy2(files[0], dst)
    print(f'iOS IPA: {dst}')


def main():
    ap = argparse.ArgumentParser(description='Build Atlas One mobile app')
    ap.add_argument('target', choices=['android', 'ios', 'all'], nargs='?', default='android')
    args = ap.parse_args()
    prepare()
    if args.target in ('android', 'all'):
        build_android()
    if args.target in ('ios', 'all'):
        build_ios()

if __name__ == '__main__':
    main()
