@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r2-v1.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R2 Repair V1 failed with exit code %EXITCODE%.
  echo Upload the ZIP under tools\dev\logs\phase008r2-repair-v1-*.zip
)

exit /b %EXITCODE%
