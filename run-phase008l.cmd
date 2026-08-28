@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008l-skill-mastery.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008L failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008l-skill-mastery-*.log
)

exit /b %EXITCODE%
