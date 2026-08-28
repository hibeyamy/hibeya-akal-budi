@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008k-prerequisite-eligibility.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008K failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008k-prerequisite-eligibility-*.log
)

exit /b %EXITCODE%
