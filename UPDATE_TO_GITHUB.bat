@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo =====================================================
echo        ATLAS ONE - UPDATE TO GITHUB + BUILD APK
echo =====================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0UPDATE_TO_GITHUB.ps1"
if errorlevel 1 (
  echo.
  echo UPDATE FAILED - read the error above.
  pause
  exit /b 1
)
echo.
echo GitHub updated. The Android APK workflow starts automatically.
echo Wait for the green build and download artifact: Atlas-One-Android-APK
pause
