@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008p-activity-diversity.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008P failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008p-activity-diversity-*.log
)

exit /b %EXITCODE%
