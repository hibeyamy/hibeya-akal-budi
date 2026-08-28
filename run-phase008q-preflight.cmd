@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008q-preflight-difficulty-progression.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008Q preflight failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008q-difficulty-progression-contract-*.txt
)

exit /b %EXITCODE%
