@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase006b-v9.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006B Repair V9 failed with exit code %EXITCODE%.
  echo Check tools\dev\logs\phase006b-v9-repair-*.log
)
exit /b %EXITCODE%
