@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3b5-v2.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3B.5 Repair V2 failed with exit code %EXITCODE%.
  echo Upload tools\dev\logs\phase008r3b5-repair-v2-*.zip
)

exit /b %EXITCODE%
