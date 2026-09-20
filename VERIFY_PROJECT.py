#!/usr/bin/env python3
from pathlib import Path
import sys
import yaml

ROOT = Path(__file__).resolve().parent
required = [
    'pubspec.yaml',
    'build.py',
    'UPDATE_TO_GITHUB.bat',
    'UPDATE_TO_GITHUB.ps1',
    '.github/workflows/build-android-apk.yml',
    '.github/workflows/validate-ios.yml',
    'lib/core/assistant_controller.dart',
    'lib/core/ai_service.dart',
    'lib/core/voice_service.dart',
    'lib/core/memory_service.dart',
    'lib/core/camera_service.dart',
    'native/android/app/src/main/AndroidManifest.xml',
    'native/android/app/src/main/kotlin/com/atlas/one/MainActivity.kt',
    'native/android/app/src/main/kotlin/com/atlas/one/ScreenCaptureService.kt',
    'native/ios/Runner/AppDelegate.swift',
]

missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    print('FAIL: missing files:')
    for p in missing: print(' -', p)
    sys.exit(1)

for workflow in [
    ROOT / '.github/workflows/build-android-apk.yml',
    ROOT / '.github/workflows/validate-ios.yml',
]:
    with workflow.open('r', encoding='utf-8') as f:
        yaml.safe_load(f)

# Guard against the placeholder URL mistake that caused an earlier failed upload.
for script in [ROOT / 'UPDATE_TO_GITHUB.ps1', ROOT / 'UPDATE_TO_GITHUB.bat']:
    text = script.read_text(encoding='utf-8', errors='replace')
    if 'github.com/USERNAME/' in text:
        print(f'FAIL: literal USERNAME placeholder found in {script.name}')
        sys.exit(1)

checks = {
    'Persian shutdown phrase': 'خاموش شو',
    'goodbye with user name': "خداحافظ",
    'screen vision': 'startScreenVision',
    'camera vision': 'toggleCamera',
    'long-term memory': 'semanticSearch',
    'app allow-list': 'allowedAppIds',
    'GitHub update': 'UPDATE_TO_GITHUB',
}
combined = '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in ROOT.rglob('*') if p.is_file())
for label, needle in checks.items():
    if needle not in combined:
        print(f'FAIL: capability marker missing: {label}')
        sys.exit(1)

print('PASS: required files, workflows, updater, and capability markers are present.')
