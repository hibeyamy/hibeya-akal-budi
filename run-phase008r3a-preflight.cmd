@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3a-preflight-visual-review.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A preflight failed with exit code %EXITCODE%.
  echo Upload the ZIP under tools\dev\logs\phase008r3a-visual-review-preflight-*.zip
)

exit /b %EXITCODE%
