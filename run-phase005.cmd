@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase005-manifest-content-compiler.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 005 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs for the generated diagnostic.
)
exit /b %EXITCODE%
