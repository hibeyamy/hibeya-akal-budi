@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008f-v7.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008F Repair V7 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008f-repair-v7-*.log
)

exit /b %EXITCODE%
