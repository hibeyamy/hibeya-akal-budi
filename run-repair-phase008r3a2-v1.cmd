@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3a2-v1.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.2 Repair V1 failed with exit code %EXITCODE%.
  echo Upload the newest tools\dev\logs\phase008r3a2-repair-v1-*.zip
)

exit /b %EXITCODE%
