@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3b5-v1.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" echo Upload tools\dev\logs\phase008r3b5-repair-v1-*.zip
exit /b %EXITCODE%
