#!/usr/bin/env bash
set -euo pipefail
mkdir -p vendor
if [ ! -f vendor/llama.cpp/examples/llama.android/lib/build.gradle.kts ]; then
  git clone --branch v0.6.0 --depth 1 --recurse-submodules https://github.com/ggml-org/llama.cpp.git vendor/llama.cpp
fi
[ -f vendor/llama.cpp/examples/llama.android/lib/build.gradle.kts ] || { echo 'llama.cpp Android inference library missing'; exit 1; }
echo "Official llama.cpp Android library available."
