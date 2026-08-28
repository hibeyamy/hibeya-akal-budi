@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008e-production-learner-journey.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008E failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008e-*.log
)

exit /b %EXITCODE%
