@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008a-learner-ux-shell.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008A failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008a-*.log
)

exit /b %EXITCODE%
