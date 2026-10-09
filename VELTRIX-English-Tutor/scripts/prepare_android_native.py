#!/usr/bin/env python3
"""Constrain upstream llama.cpp Android AAR to the target ARM64 architecture.
Avoid compiling x86_64 native backends for an ARM64-only APK.
This does not suppress errors or substitute a fake model engine.
"""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
gradle = root / 'vendor/llama.cpp/examples/llama.android/lib/build.gradle.kts'
if not gradle.is_file():
    sys.exit(f'ERROR: official llama.cpp library missing: {gradle}')
s = gradle.read_text(encoding='utf8')
old = s
pat = r'abiFilters\s*\+=\s*listOf\(\s*"arm64-v8a"\s*,\s*"x86_64"\s*\)'
s = re.sub(pat, 'abiFilters += listOf("arm64-v8a")', s)
if 'arm64-v8a' not in s:
    sys.exit('ERROR: cannot verify ARM64 ABI in upstream native module; inspect upstream build.gradle.kts')
if s != old:
    gradle.write_text(s, encoding='utf8')
print('ARM64-only ABI configured for official llama.cpp Android library')
# Explicitly check known interface, fail before a lengthy  native compile if it differs.
sdk = root / 'vendor/llama.cpp/examples/llama.android/lib/src/main/java/com/arm/aichat/InferenceEngine.kt'
if not sdk.is_file():
    sys.exit('ERROR: upstream InferenceEngine.kt missing; check pinned llama.cpp version')
api = sdk.read_text(encoding='utf8')
required = ['sendUserPrompt(', 'loadModel(', 'cleanUp(', 'destroy(', 'class State', 'Initialized']
absent = [s for s in required if s not in api]
if absent:
    sys.exit('ERROR: official inference API incompatible; missing: ' + ', '.join(absent))
print('Inference API surface validated: ' + ', '.join(required))
