@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================
echo       ATLAS ONE - CLOUD APK UPLOADER
echo ============================================
echo.
where git >nul 2>nul
if errorlevel 1 (
  echo ERROR: Git is not available in PATH.
  echo Close and reopen PowerShell/Windows Terminal, then try again.
  pause
  exit /b 1
)

set /p REPO=Paste EMPTY GitHub repository URL: 
if "%REPO%"=="" (
  echo ERROR: Repository URL is required.
  pause
  exit /b 1
)

if not exist ".git" (
  git init
)

git checkout -B main
git add .
git config user.name >nul 2>nul || git config user.name "Atlas Builder"
git config user.email >nul 2>nul || git config user.email "atlas-builder@users.noreply.github.com"
git commit -m "Atlas One Android cloud build" 2>nul || echo Nothing new to commit.

git remote remove origin >nul 2>nul
git remote add origin "%REPO%"

echo.
echo Uploading Atlas to GitHub...
git push -u origin main --force
if errorlevel 1 (
  echo.
  echo PUSH FAILED.
  echo If GitHub asks for authentication, sign in using the browser or Git Credential Manager,
  echo then run this file again.
  pause
  exit /b 1
)

echo.
echo SUCCESS.
echo Open this URL in your browser:
set WEB=%REPO:.git=%
echo %WEB%/actions
start "" "%WEB%/actions"
echo.
echo In GitHub: Actions ^> Build Atlas Android APK ^> Run workflow.
pause
