@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007b-illustration-language.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 007B failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007b-*.log
)
exit /b %EXITCODE%
