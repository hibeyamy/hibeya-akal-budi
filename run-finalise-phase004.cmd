@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0finalise-phase004.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Final Phase 004 integration failed with exit code %EXITCODE%.
  echo Review tools\dev\logs for the generated diagnostic.
)
exit /b %EXITCODE%
