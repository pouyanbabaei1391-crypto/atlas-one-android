@echo off
cd /d "%~dp0"
set ATLAS_BUNDLE_MODEL=true
python english_voice_addon\build.py android
if errorlevel 1 (
  echo Build failed. Read the error above.
  pause
  exit /b 1
)
start "" "%~dp0dist"
pause
