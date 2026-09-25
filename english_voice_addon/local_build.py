"""Configure only the disposable Android build; original project files stay intact."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import urllib.request

MODEL_URL = 'https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/cc27747d7419139e44ba97777c2f2fd5dca92ee1/Qwen3-1.7B-Q4_K_M.gguf?download=true'
MODEL_SIZE = 1107409376
MODEL_SHA256 = 'ba491cf470c3cadc624e4c8d6c9a27c998809e8ba8eb938d1689ae87e024b6b7'
PART_SIZE = 128 * 1024 * 1024

def bundle_model(destination: Path):
    destination.mkdir(parents=True, exist_ok=True)
    for old in destination.glob('part-*.ggufpart'):
        old.unlink()
    digest = hashlib.sha256()
    copied = 0
    part = None
    try:
        with urllib.request.urlopen(MODEL_URL, timeout=60) as source:
            while True:
                data = source.read(min(1024 * 1024, PART_SIZE - copied % PART_SIZE))
                if not data:
                    break
                if copied % PART_SIZE == 0:
                    if part:
                        part.close()
                    part = (destination / f'part-{copied // PART_SIZE:03d}.ggufpart').open('wb')
                part.write(data)
                digest.update(data)
                copied += len(data)
                if copied > MODEL_SIZE:
                    raise RuntimeError('Downloaded model exceeds expected size')
                if copied % PART_SIZE == 0:
                    print(f'Bundling Qwen3: {copied / MODEL_SIZE:.0%}', flush=True)
        if copied != MODEL_SIZE or digest.hexdigest() != MODEL_SHA256:
            raise RuntimeError('Qwen3 size/SHA-256 check failed; refusing to build')
    except BaseException:
        if part:
            part.close()
        for file in destination.glob('part-*.ggufpart'):
            file.unlink()
        raise
    finally:
        if part:
            part.close()
    (destination / 'model.json').write_text(json.dumps({'size': copied, 'sha256': MODEL_SHA256}))

def link_or_copy(source, destination):
    target = Path(destination)
    if target.exists() or target.is_symlink():
        target.unlink()
    try:
        os.link(source, destination)
        return str(destination)
    except OSError:
        return shutil.copy2(source, destination)

def configure(work: Path):
    path = work / 'android/app/build.gradle.kts'
    if not path.exists():
        raise RuntimeError('Local Qwen3 build expects current Flutter Kotlin Gradle templates.')
    with path.open('a', encoding='utf-8') as output:
        output.write('\nandroid {\n    defaultConfig {\n        minSdk = 28\n        ndk { abiFilters.clear(); abiFilters.add("arm64-v8a") }\n        externalNativeBuild {\n            cmake { arguments.add("-DANDROID_STL=c++_shared") }\n        }\n    }\n    externalNativeBuild {\n        cmake {\n            path = file("src/main/cpp/CMakeLists.txt")\n            version = "3.22.1"\n        }\n    }\n    androidResources { noCompress.add("ggufpart") }\n}\n')
