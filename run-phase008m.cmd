@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008m-adaptive-progression.ps1"

set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008M failed with exit code %EXITCODE%.
)
exit /b %EXITCODE%
