@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================
echo     ATLAS ONE - PUSH CLOUD BUILD FIX
echo ============================================
echo.
where git >nul 2>nul
if errorlevel 1 (
  echo ERROR: Git is not available in PATH.
  pause
  exit /b 1
)

if not exist ".git" (
  echo This folder is not yet linked to GitHub.
  set /p REPO=Paste your GitHub repository URL: 
  git init
  git checkout -B main
  git remote add origin "%REPO%"
) else (
  git checkout -B main
)

git add .github/workflows/build-android-apk.yml
git commit -m "Fix Android cloud build bootstrap" 2>nul || echo Workflow already committed.
git push -u origin main
if errorlevel 1 (
  echo.
  echo PUSH FAILED. Sign in to GitHub if prompted, then run this file again.
  pause
  exit /b 1
)

echo.
echo SUCCESS. GitHub Actions will start automatically.
for /f "delims=" %%R in ('git remote get-url origin') do set REPO=%%R
set WEB=%REPO:.git=%
start "" "%WEB%/actions"
pause
