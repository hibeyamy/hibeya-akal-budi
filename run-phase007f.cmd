@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007f-manifest-commercial-registry.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007F failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007f-*.log
)

exit /b %EXITCODE%
