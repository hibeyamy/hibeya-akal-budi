@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase007g-v2-runner.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007G V2 runner repair failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007g-v2-repair-*.log
)
exit /b %EXITCODE%
