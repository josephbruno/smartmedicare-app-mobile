@echo off
setlocal EnableExtensions

rem ============================================================
rem  Maran Billing — build Windows release + single setup EXE
rem
rem  Usage:
rem    build-single-exe.bat
rem    build-single-exe.bat --skip-build
rem    build-single-exe.bat --api-base https://api-maran.biapps.cloud/api/v1
rem    build-single-exe.bat --output-dir D:\releases\maran
rem
rem  Requires: Flutter + Inno Setup 6 (ISCC.exe)
rem  Output:   dist\windows\MaranBilling-Setup-<version>.exe
rem ============================================================

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%build-windows-installer.ps1"

cd /d "%SCRIPT_DIR%.."
if errorlevel 1 (
  echo ERROR: cannot cd to project root
  exit /b 1
)

if not exist "%PS1%" (
  echo ERROR: missing %PS1%
  exit /b 1
)

set "SKIP_BUILD=0"
set "OUTPUT_DIR="

if "%MARAN_API_BASE%"=="" (
  set "API_BASE=https://api-maran.biapps.cloud/api/v1"
) else (
  set "API_BASE=%MARAN_API_BASE%"
)

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--skip-build" (
  set "SKIP_BUILD=1"
  shift
  goto parse
)
if /i "%~1"=="--api-base" (
  set "API_BASE=%~2"
  shift
  shift
  goto parse
)
if /i "%~1"=="--output-dir" (
  set "OUTPUT_DIR=%~2"
  shift
  shift
  goto parse
)
if /i "%~1"=="--help" (
  echo Usage: %~nx0 [--skip-build] [--api-base URL] [--output-dir DIR]
  echo.
  echo Builds Flutter Windows release and packages a single Inno Setup EXE.
  echo Output: dist\windows\MaranBilling-Setup-^<version^>.exe
  exit /b 0
)
echo Unknown option: %~1
echo Run %~nx0 --help
exit /b 1

:parsed

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found in PATH
  exit /b 1
)

echo.
echo == Maran single EXE installer ==
echo    API base : %API_BASE%
if not "%OUTPUT_DIR%"=="" echo    Output   : %OUTPUT_DIR%
echo    SkipBuild: %SKIP_BUILD%
echo    Script   : %PS1%
echo.

if "%SKIP_BUILD%"=="1" goto run_skip
if not "%OUTPUT_DIR%"=="" (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%PS1%" -ApiBaseUrl "%API_BASE%" -OutputDir "%OUTPUT_DIR%"
) else (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%PS1%" -ApiBaseUrl "%API_BASE%"
)
goto after_ps

:run_skip
if not "%OUTPUT_DIR%"=="" (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%PS1%" -SkipBuild -ApiBaseUrl "%API_BASE%" -OutputDir "%OUTPUT_DIR%"
) else (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%PS1%" -SkipBuild -ApiBaseUrl "%API_BASE%"
)

:after_ps
if errorlevel 1 (
  echo.
  echo ERROR: installer build failed
  echo - Install Inno Setup 6 from https://jrsoftware.org/isinfo.php
  echo - Ensure flutter build windows works
  exit /b 1
)

echo.
echo Single EXE ready under dist\windows\
if "%MARAN_SIGN_PFX_PATH%"=="" (
  echo.
  echo WARNING: Unsigned installer — SmartScreen will show "Unknown publisher".
  echo   setx MARAN_SIGN_PFX_PATH "C:\certs\your.pfx"
  echo   setx MARAN_SIGN_PFX_PASSWORD "your-password"
  echo   Then rebuild. Temporary workaround: More info -^> Run anyway
)
exit /b 0
