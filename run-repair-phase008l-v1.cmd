@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008l-v1.ps1"

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008L Repair V1 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008l-repair-v1-*.log
)

exit /b %EXITCODE%
