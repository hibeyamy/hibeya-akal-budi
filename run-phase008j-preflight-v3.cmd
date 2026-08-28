@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008j-preflight-v3.ps1"

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008J preflight V3 failed with exit code %EXITCODE%.
)

exit /b %EXITCODE%
