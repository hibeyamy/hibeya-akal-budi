@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008l-v2.ps1"

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008L Repair V2 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008l-repair-v2-*.log
)

exit /b %EXITCODE%
