@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3b2-preflight.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3B.2 preflight failed with exit code %EXITCODE%.
  echo Upload tools\dev\logs\phase008r3b2-child-facing-visual-system-preflight-*.zip
)

exit /b %EXITCODE%
