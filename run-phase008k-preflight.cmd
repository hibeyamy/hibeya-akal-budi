@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008k-preflight-prerequisite-eligibility.ps1"

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008K preflight failed with exit code %EXITCODE%.
)

exit /b %EXITCODE%
