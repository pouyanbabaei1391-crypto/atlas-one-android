"""Dependency-free structural source tests; Flutter tests run in GitHub Actions."""
from pathlib import Path
from xml.etree import ElementTree as ET
import subprocess

root = Path(__file__).resolve().parent
required = [
    'lib/main.dart','lib/screens/veltrix_home_screen.dart',
    'lib/language/english_coach_controller.dart','lib/language/english_voice_service.dart',
    'lib/language/gemma_coach_service.dart','lib/language/lesson_turn.dart',
    'lib/widgets/veltrix_avatar.dart', '.github/workflows/build-android-apk.yml',
    'UPDATE_TO_GITHUB.bat','UPDATE_TO_GITHUB.ps1','.atlas_repo_url',
    'web_preview/index.html','web_preview/style.css','web_preview/preview.js',
]
for filename in required:
    assert (root/filename).is_file(),f'Missing {filename}'
assert 'github.com/pouyanbabaei1391-crypto/atlas-one-android.git' in (root/'.atlas_repo_url').read_text()
assert 'gemma3:4b' in (root/'lib/language/gemma_coach_service.dart').read_text()
assert 'speech_to_text' in (root/'lib/language/english_voice_service.dart').read_text()
assert 'flutter_tts' in (root/'lib/language/english_voice_service.dart').read_text()
assert 'VELTRIX-AI-English-Mastery-APK' in (root/'.github/workflows/build-android-apk.yml').read_text()
assert 'Atlas-One-Android-APK' in (root/'.github/workflows/build-android-apk.yml').read_text()
ET.parse(root/'native/android/app/src/main/AndroidManifest.xml')
subprocess.run(['node','--check',str(root/'web_preview/preview.js')],check=True)
for target in ('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi'):
    assert (root/'native/android/app/src/main/res'/target/'ic_launcher.png').stat().st_size>0
print('PASS: 14 required files, unchanged remote URL, Gemma selection, STT/TTS hooks,')
print('      original GitHub artifact + VELTRIX artifact, XML, JS and 5 Android icon densities.')
