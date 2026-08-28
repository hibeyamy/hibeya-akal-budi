@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008d-activityplayer-adapter.ps1" %*
exit /b %ERRORLEVEL%
