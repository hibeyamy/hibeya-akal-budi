@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase006b-v7.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006B V7 failed with exit code %EXITCODE%.
  echo Check tools\dev\logs\phase006b-v7-session-*.log for diagnostics.
)
exit /b %EXITCODE%
