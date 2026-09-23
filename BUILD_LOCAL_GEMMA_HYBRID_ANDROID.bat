@echo off
setlocal
cd /d "%~dp0"
if "%ATLAS_HYBRID_GATEWAY_URL%"=="" (
  echo Set ATLAS_HYBRID_GATEWAY_URL to your deployed Gateway URL first.
  exit /b 2
)
set "ATLAS_BUNDLE_MODEL=false"
set "ATLAS_HYBRID_CLOUD_MODEL=llama-3.1-8b-instant"
python hybrid_voice_addon\build.py android
if errorlevel 1 exit /b %errorlevel%
python english_voice_addon\verify_slim_apk.py dist\Atlas-One-Android.apk --max-bytes 800000000
if errorlevel 1 exit /b %errorlevel%
echo Hybrid APK verified: dist\Atlas-One-Android.apk
endlocal

