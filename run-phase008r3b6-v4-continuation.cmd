@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3b6-v4-continuation.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" echo Upload tools\dev\logs\phase008r3b6-v4-continuation-*.zip
exit /b %EXITCODE%
