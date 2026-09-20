@echo off
setlocal
cd /d "%~dp0"
python build.py android
if errorlevel 1 pause
endlocal
