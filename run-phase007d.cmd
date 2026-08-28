@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007d-first-original-asset-batch.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007D failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007d-*.log
)
exit /b %EXITCODE%
