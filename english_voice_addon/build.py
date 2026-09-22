"""Build the English voice edition without changing any original source file."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

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
    subprocess.run(['flutter', 'pub', 'get'], cwd=stage, check=True)
    subprocess.run(['flutter', 'test'], cwd=stage, check=True)
    subprocess.run([sys.executable, 'build.py', args.target], cwd=stage, check=True)
    shutil.copytree(stage / 'dist', ROOT / 'dist', dirs_exist_ok=True)

if __name__ == '__main__':
    main()
