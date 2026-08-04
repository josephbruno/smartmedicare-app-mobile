@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem  Maran Billing — build Windows release, ZIP, upload to API
rem
rem  Usage:
rem    build-zip-upload-update.bat
rem    build-zip-upload-update.bat --skip-build
rem    build-zip-upload-update.bat --mandatory
rem    build-zip-upload-update.bat --notes "POS fixes"
rem
rem  Required env (set once on your PC):
rem    setx MARAN_DEPLOY_TOKEN "your-long-secret"
rem
rem  Optional env:
rem    MARAN_API_BASE   default: https://api-maran.biapps.cloud/api/v1
rem ============================================================

cd /d "%~dp0\.."
if errorlevel 1 (
  echo ERROR: cannot cd to project root
  exit /b 1
)

set "SKIP_BUILD=0"
set "MANDATORY=0"
set "NOTES="

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--skip-build" (
  set "SKIP_BUILD=1"
  shift
  goto parse
)
if /i "%~1"=="--mandatory" (
  set "MANDATORY=1"
  shift
  goto parse
)
if /i "%~1"=="--notes" (
  set "NOTES=%~2"
  shift
  shift
  goto parse
)
if /i "%~1"=="--help" (
  echo Usage: %~nx0 [--skip-build] [--mandatory] [--notes "text"]
  exit /b 0
)
echo Unknown option: %~1
exit /b 1

:parsed

if "%MARAN_API_BASE%"=="" set "MARAN_API_BASE=https://api-maran.biapps.cloud/api/v1"
if "%MARAN_DEPLOY_TOKEN%"=="" (
  echo ERROR: MARAN_DEPLOY_TOKEN is not set.
  echo Run: setx MARAN_DEPLOY_TOKEN "your-long-secret"
  echo Then open a NEW terminal and retry.
  echo The same value must be in server .env as APP_UPDATE_DEPLOY_TOKEN.
  exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not found in PATH
  exit /b 1
)

where curl >nul 2>&1
if errorlevel 1 (
  echo ERROR: curl not found in PATH
  exit /b 1
)

rem ---- read version from pubspec.yaml (1.0.0+1) ----
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command ^
  "(Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()"`) do (
  set "VERSION_LINE=%%V"
)
if "%VERSION_LINE%"=="" (
  echo ERROR: could not read version from pubspec.yaml
  exit /b 1
)

for /f "tokens=1,2 delims=+" %%A in ("%VERSION_LINE%") do (
  set "VERSION=%%A"
  set "BUILD_NUM=%%B"
)
if "%BUILD_NUM%"=="" set "BUILD_NUM=1"
if "%NOTES%"=="" set "NOTES=Release %VERSION%+%BUILD_NUM%"

set "RELEASE_DIR=build\windows\x64\runner\Release"
set "OUT_DIR=dist\windows"
set "ZIP_NAME=maran-%VERSION%+%BUILD_NUM%.zip"
set "ZIP_PATH=%OUT_DIR%\%ZIP_NAME%"
set "PUBLISH_URL=%MARAN_API_BASE%/app/updates/publish"
set "UPDATER_SRC=%~dp0..\updater"

echo.
echo == Maran Windows update publish ==
echo    Version  : %VERSION%+%BUILD_NUM%
echo    API      : %PUBLISH_URL%
echo    ZIP      : %ZIP_PATH%
echo    Mandatory: %MANDATORY%
echo.

if "%SKIP_BUILD%"=="1" goto stage_updater

echo ==> Building Flutter Windows release...
flutter build windows --release --dart-define=API_BASE_URL=%MARAN_API_BASE%
if errorlevel 1 (
  echo ERROR: flutter build failed
  exit /b 1
)

:stage_updater
if not exist "%RELEASE_DIR%\mobile.exe" (
  echo ERROR: missing %RELEASE_DIR%\mobile.exe
  echo Build first or remove --skip-build
  exit /b 1
)

echo ==> Staging Update.bat / Update.ps1 into Release folder...
copy /Y "%UPDATER_SRC%\Update.bat" "%RELEASE_DIR%\Update.bat" >nul
if errorlevel 1 (
  echo ERROR: failed to copy Update.bat
  exit /b 1
)
copy /Y "%UPDATER_SRC%\Update.ps1" "%RELEASE_DIR%\Update.ps1" >nul
if errorlevel 1 (
  echo ERROR: failed to copy Update.ps1
  exit /b 1
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo ==> Creating ZIP...
if exist "%ZIP_PATH%" del /f /q "%ZIP_PATH%"

powershell -NoProfile -Command ^
  "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%ZIP_PATH%' -Force"
if errorlevel 1 (
  echo ERROR: zip failed
  exit /b 1
)

echo ==> Uploading to server...
curl.exe -f -S -X POST "%PUBLISH_URL%" ^
  -H "X-Deploy-Token: %MARAN_DEPLOY_TOKEN%" ^
  -F "platform=windows" ^
  -F "version=%VERSION%" ^
  -F "build_number=%BUILD_NUM%" ^
  -F "mandatory=%MANDATORY%" ^
  -F "release_notes=%NOTES%" ^
  -F "package=@%ZIP_PATH%;type=application/zip"

if errorlevel 1 (
  echo.
  echo ERROR: upload failed
  echo - Deploy backend migration + APP_UPDATE_DEPLOY_TOKEN
  echo - Ensure php/nginx allow large uploads ^(500MB^)
  echo - php artisan storage:link
  exit /b 1
)

echo.
echo Done.
echo   ZIP uploaded: %ZIP_NAME%
echo   Check: %MARAN_API_BASE%/app/updates/check?platform=windows^&current_build=1
echo.
exit /b 0
