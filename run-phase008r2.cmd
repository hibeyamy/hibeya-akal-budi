@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r2-first-governed-content-pack.ps1"

set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R2 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008r2-first-governed-content-pack-*.log
)

exit /b %EXITCODE%
