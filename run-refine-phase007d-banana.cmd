@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0refine-phase007d-banana.ps1"
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Banana refinement failed with exit code %EXITCODE%.
  echo Review tools\dev\logs\phase007d-banana-refinement-*.log
)
exit /b %EXITCODE%
