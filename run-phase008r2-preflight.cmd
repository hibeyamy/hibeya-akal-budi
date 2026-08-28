@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r2-preflight-content-pack.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R2 preflight failed with exit code %EXITCODE%.
  echo Review the ZIP under tools\dev\logs\phase008r2-content-pack-preflight-*.zip
)

exit /b %EXITCODE%
