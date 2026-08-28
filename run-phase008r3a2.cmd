@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3a2-asset-architecture-foundation.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.2 failed with exit code %EXITCODE%.
  echo Upload the newest tools\dev\logs\phase008r3a2-asset-foundation-*.zip
)

exit /b %EXITCODE%
