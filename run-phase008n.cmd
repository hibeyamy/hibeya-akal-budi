@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008n-review-remediation.ps1"

set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008N failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008n-review-remediation-*.log
)
exit /b %EXITCODE%
