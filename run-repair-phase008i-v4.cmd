@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008i-v4.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008I Repair V4 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008i-repair-v4-*.log
)

exit /b %EXITCODE%
