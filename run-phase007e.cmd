@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007e-scalable-asset-families.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007E failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007e-*.log
)
exit /b %EXITCODE%
