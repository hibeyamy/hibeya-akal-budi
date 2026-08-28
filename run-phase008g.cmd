@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008g-learner-progress.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008G failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008g-*.log
)

exit /b %EXITCODE%
