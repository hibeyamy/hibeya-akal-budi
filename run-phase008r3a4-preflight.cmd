@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3a4-preflight-raster-pipeline.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.4 preflight failed with exit code %EXITCODE%.
  echo Upload the newest tools\dev\logs\phase008r3a4-raster-pipeline-preflight-*.zip
)

exit /b %EXITCODE%
