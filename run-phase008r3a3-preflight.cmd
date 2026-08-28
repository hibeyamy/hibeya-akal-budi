@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0phase008r3a3-preflight-legacy-asset-migration.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3A.3 preflight failed with exit code %EXITCODE%.
  echo Upload the newest tools\dev\logs\phase008r3a3-legacy-asset-migration-preflight-*.zip
)
exit /b %EXITCODE%
