@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3a5b-candidate-review.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.5B failed with exit code %EXITCODE%.
  echo Upload tools\dev\logs\phase008r3a5b-candidate-review-*.zip
)
exit /b %EXITCODE%
