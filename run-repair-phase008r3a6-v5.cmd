@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3a6-v5.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.6 Repair V5 failed with exit code %EXITCODE%.
  echo Upload tools\dev\logs\phase008r3a6-repair-v5-*.zip
)

exit /b %EXITCODE%
