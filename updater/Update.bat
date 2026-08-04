@echo off
setlocal EnableExtensions
rem Launcher for Maran Billing Windows updater (PowerShell).
rem Args are forwarded as-is to Update.ps1.

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%Update.ps1"

if not exist "%PS1%" (
  echo ERROR: Update.ps1 not found next to Update.bat
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
exit /b %ERRORLEVEL%
