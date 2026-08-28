@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008j-content-sequencing.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008J failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008j-content-sequencing-*.log
)

exit /b %EXITCODE%
