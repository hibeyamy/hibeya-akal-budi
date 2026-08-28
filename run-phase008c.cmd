@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008c-learner-journey.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008C failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008c-*.log
)

exit /b %EXITCODE%
