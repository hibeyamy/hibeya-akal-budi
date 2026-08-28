@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007c-production-asset-pipeline.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007C failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007c-*.log
)
exit /b %EXITCODE%
