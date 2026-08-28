@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3b7-v1.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Phase 008R3B.7 repair v1 failed with exit code %EXITCODE%.
  echo Upload the generated ERROR ZIP from tools\dev\logs to ChatGPT.
)
exit /b %EXITCODE%
