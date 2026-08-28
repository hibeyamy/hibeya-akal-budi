@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007h-format-agnostic-assets.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007H failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007h-*.log
)

exit /b %EXITCODE%
