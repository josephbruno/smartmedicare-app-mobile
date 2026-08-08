@echo off
setlocal EnableExtensions
rem Launcher for Maran Billing Windows updater (PowerShell).
rem Forwards args with quoting preserved where possible.

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%Update.ps1"

if not exist "%PS1%" (
  echo ERROR: Update.ps1 not found next to Update.bat
  exit /b 1
)

rem Use %* so quoted paths with spaces (e.g. "...\Maran Billing") stay intact.
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%PS1%" %*
exit /b %ERRORLEVEL%
