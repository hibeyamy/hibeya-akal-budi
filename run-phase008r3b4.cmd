@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3b4-responsive-qa.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
 echo.
 echo Phase 008R3B.4 failed with exit code %EXITCODE%.
 echo Upload tools\dev\logs\phase008r3b4-responsive-qa-*.zip
)
exit /b %EXITCODE%
