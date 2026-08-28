@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r1-preflight-content-pack-contract.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R1 preflight failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008r1-content-pack-contract-*.txt
)

exit /b %EXITCODE%
