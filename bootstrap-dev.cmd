@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\dev\bootstrap-dev.ps1" %*
set EXITCODE=%ERRORLEVEL%
exit /b %EXITCODE%
