@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3a5c-preflight.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.5C preflight failed with exit code %EXITCODE%.
  echo Upload tools\dev\logs\phase008r3a5c-controlled-promotion-preflight-*.zip
)

exit /b %EXITCODE%
