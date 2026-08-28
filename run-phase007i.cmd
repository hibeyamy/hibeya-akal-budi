@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007i-runtime-image-optimisation.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007I failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007i-*.log
)

exit /b %EXITCODE%
