@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008h-unique-completion.ps1"
exit /b %ERRORLEVEL%
