@echo off
setlocal
cd /d "%~dp0"
set "ATLAS_BUNDLE_MODEL=false"
python english_voice_addon\build.py android
if errorlevel 1 exit /b %errorlevel%
python english_voice_addon\verify_slim_apk.py dist\Atlas-One-Android.apk --max-bytes 800000000
if errorlevel 1 exit /b %errorlevel%
echo.
echo Slim APK verified: dist\Atlas-One-Android.apk
endlocal

