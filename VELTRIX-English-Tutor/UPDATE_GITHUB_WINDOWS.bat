@echo off
setlocal EnableExtensions
rem Backward compatible launcher. Call the ROOT BAT by its full path, never itself.
if not exist "%~dp0..\UPDATE_GITHUB_WINDOWS.bat" (
 echo [ERROR] Root UPDATE_GITHUB_WINDOWS.bat missing. Extract ALL ZIP files.
 pause
 exit /b 2
)
call "%~dp0..\UPDATE_GITHUB_WINDOWS.bat"
exit /b %ERRORLEVEL%
