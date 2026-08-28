@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase006c-app-design-adoption.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006C failed with exit code %EXITCODE%.
  echo Check tools\dev\logs\phase006c-*.log
)
exit /b %EXITCODE%
