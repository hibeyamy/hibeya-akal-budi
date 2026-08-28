@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3b6-governed-promotion.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
 echo.
 echo R3B.6 governed promotion failed with exit code %EXITCODE%.
 echo Upload tools\dev\logs\phase008r3b6-governed-promotion-*.zip
)
exit /b %EXITCODE%
