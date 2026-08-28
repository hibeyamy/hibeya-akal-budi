@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007a-original-asset-provenance.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007A failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007a-*.log
)

exit /b %EXITCODE%
