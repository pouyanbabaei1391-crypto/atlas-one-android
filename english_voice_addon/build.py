"""Build the English voice edition without changing any original source file."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import os
from local_build import bundle_model, link_or_copy

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / '.build' / 'english_voice_source'

def prepare():
    STAGE.mkdir(parents=True, exist_ok=True)
    for name in ('lib', 'native', 'test'):
        if (ROOT / name).exists():
            shutil.copytree(ROOT / name, STAGE / name, dirs_exist_ok=True)
    for name in ('build.py', 'pubspec.yaml', 'analysis_options.yaml'):
        shutil.copy2(ROOT / name, STAGE / name)
    shutil.copytree(ROOT / 'english_voice_addon' / 'overlay', STAGE, dirs_exist_ok=True)
    # Only the disposable staging copy changes; the original builder is untouched.
    builder = STAGE / 'build.py'
    builder.write_text(builder.read_text(encoding='utf-8').replace('Persian voice conversation', 'English voice conversation').replace('Persian speech', 'English speech'), encoding='utf-8')
    shutil.copy2(ROOT / 'english_voice_addon' / 'local_build.py', STAGE / 'local_build.py')
    builder_text = builder.read_text(encoding='utf-8').replace("import argparse", "import argparse\nfrom local_build import link_or_copy")
    builder_text = builder_text.replace('    patch_android(work)', '    patch_android(work)\n    from local_build import configure\n    configure(work)')
    builder_text = builder_text.replace('["flutter", "build", "apk", "--release"]', '["flutter", "build", "apk", "--release", "--target-platform", "android-arm64"]')
    build_command = ["flutter", "build", "apk", "--release", "--target-platform", "android-arm64"]
    for env_name, dart_name in (
        ('ATLAS_SERVER_URL', 'ATLAS_SERVER_URL'),
        ('ATLAS_SERVER_MODEL', 'ATLAS_SERVER_MODEL'),
        ('ATLAS_SERVER_API_KEY', 'ATLAS_SERVER_API_KEY'),
    ):
        value = os.environ.get(env_name, '').strip()
        if value:
            build_command.append(f'--dart-define={dart_name}={value}')
    builder_text = builder_text.replace(
        '["flutter", "build", "apk", "--release", "--target-platform", "android-arm64"]',
        json.dumps(build_command),
    )
    # Hard-link large model chunks within the same build volume to avoid redundant copies.
    builder_text = builder_text.replace('shutil.copytree(item, target, dirs_exist_ok=True)', 'shutil.copytree(item, target, dirs_exist_ok=True, copy_function=link_or_copy)')
    builder_text = builder_text.replace('shutil.copy2(src, dst)', 'link_or_copy(src, dst)')
    builder.write_text(builder_text, encoding='utf-8')
    return STAGE

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('target', nargs='?', default='android', choices=['android', 'ios-unsigned', 'ios-signed'])
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    stage = prepare()
    if args.prepare_only:
        print(stage)
        return
    if args.target == 'android' and os.environ.get('ATLAS_BUNDLE_MODEL', 'true').lower() == 'true':
        bundle_model(stage / 'native/android/app/src/main/assets/gemma')
    subprocess.run(['flutter', 'pub', 'get'], cwd=stage, check=True)
    subprocess.run(['flutter', 'analyze', '--no-fatal-infos', '--no-fatal-warnings', 'lib', 'test'], cwd=stage, check=True)
    subprocess.run(['flutter', 'test'], cwd=stage, check=True)
    subprocess.run([sys.executable, 'build.py', args.target], cwd=stage, check=True)
    shutil.copytree(stage / 'dist', ROOT / 'dist', dirs_exist_ok=True, copy_function=link_or_copy)

if __name__ == '__main__':
    main()
