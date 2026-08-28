@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3b7-persistence-resume.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3B.7 failed with exit code %EXITCODE%.
  echo Review tools\dev\logs for diagnostics.
)
exit /b %EXITCODE%
