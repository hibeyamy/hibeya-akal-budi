@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008f-learner-journey-e2e.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008F failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008f-*.log
)

exit /b %EXITCODE%
