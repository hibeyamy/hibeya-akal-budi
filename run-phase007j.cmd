@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase007j-asset-vault.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
 echo.
 echo Phase 007J failed with exit code %EXITCODE%.
 echo Review tools\dev\logs\phase007j-*.log
)
exit /b %EXITCODE%
