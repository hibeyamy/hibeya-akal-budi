@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase006d-path.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006D repair failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase006d-repair-*.log
)
exit /b %EXITCODE%
