@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase006d-v3.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006D Repair V3 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase006d-repair-v3-*.log
)

exit /b %EXITCODE%
