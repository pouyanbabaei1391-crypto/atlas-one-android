$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path vendor | Out-Null
if (!(Test-Path 'vendor/llama.cpp/examples/llama.android/lib/build.gradle.kts')) {
    git clone --branch v0.6.0 --depth 1 --recurse-submodules https://github.com/ggml-org/llama.cpp.git vendor/llama.cpp
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone llama.cpp' }
}
Write-Host 'Official llama.cpp Android library available.'
