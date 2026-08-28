@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008i-modular-resume.ps1" %*

set EXITCODE=%ERRORLEVEL%

if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008I failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase008i-modular-resume-*.log
)

exit /b %EXITCODE%
