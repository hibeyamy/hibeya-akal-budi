@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r1-governed-coverage.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R1 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008r1-governed-coverage-*.log
)

exit /b %EXITCODE%
