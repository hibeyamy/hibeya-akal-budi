@echo off
setlocal EnableExtensions
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-phase008r3b7-v2.ps1" %*
set "EXITCODE=%ERRORLEVEL%"

if "%EXITCODE%"=="0" (
  exit /b 0
)

echo.
echo Phase 008R3B.7 repair v2 failed with exit code %EXITCODE%.
echo Creating / verifying ERROR ZIP using independent emergency packager...

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package-phase008r3b7-error.ps1" -RepositoryRoot "%CD%" -Prefix "repair-phase008r3b7-v2"
set "ZIPCODE=%ERRORLEVEL%"

if not "%ZIPCODE%"=="0" (
  echo.
  echo WARNING: Emergency ERROR ZIP packager also failed with exit code %ZIPCODE%.
  echo The raw log remains under tools\dev\logs.
) else (
  echo.
  echo ERROR ZIP generated under tools\dev\logs.
  echo Upload the *-ERROR.zip file to ChatGPT.
)

exit /b %EXITCODE%
