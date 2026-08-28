@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007g-original-hibiscus-batch.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007G failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007g-*.log
)

exit /b %EXITCODE%
