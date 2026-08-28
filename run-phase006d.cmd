@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase006d-accessibility-visual-regression.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 006D failed with exit code %EXITCODE%.
  echo Check tools\dev\logs\phase006d-*.log
)
exit /b %EXITCODE%
