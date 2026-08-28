@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008d-v5.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008D Repair V5 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008d-repair-v5-*.log
)

exit /b %EXITCODE%
