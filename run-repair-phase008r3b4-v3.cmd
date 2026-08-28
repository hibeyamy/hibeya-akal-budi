@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3b4-v3.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
 echo.
 echo Phase 008R3B.4 Repair V3 failed with exit code %EXITCODE%.
 echo Upload tools\dev\logs\phase008r3b4-repair-v3-*.zip
)
exit /b %EXITCODE%
