@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase006a-design-system-foundation.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006A failed with exit code %EXITCODE%.
  echo Review tools\dev\logs for diagnostics.
)
exit /b %EXITCODE%
