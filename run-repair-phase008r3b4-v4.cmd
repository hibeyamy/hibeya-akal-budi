@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3b4-v4.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
 echo.
 echo Phase 008R3B.4 Repair V4 failed with exit code %EXITCODE%.
 echo Upload tools\dev\logs\phase008r3b4-repair-v4-*.zip
)
exit /b %EXITCODE%
