@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008b-learner-runtime-integration.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
 echo.
 echo Phase 008B failed with exit code %EXITCODE%.
 echo Review tools\dev\logs\phase008b-*.log
)
exit /b %EXITCODE%
