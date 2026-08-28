@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3b5-preflight.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3B.5 preflight failed with exit code %EXITCODE%.
  echo Upload tools\dev\logs\phase008r3b5-accessibility-interaction-preflight-*.zip
)

exit /b %EXITCODE%
