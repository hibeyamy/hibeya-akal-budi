@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase007j-v2.ps1"

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007J Repair V2 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007j-repair-v2-*.log
)

exit /b %EXITCODE%
