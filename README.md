# Maran Billing — Flutter (MVVM)

Cross-platform client for the Maran Billing / PetShop SaaS API (`/api/v1`), aligned with the Vue web app in `../frontend`.

## Platforms

- Android, iOS, Windows, macOS, Linux

## Configuration

Default API base URL: `https://api-maran.biapps.cloud/api/v1`

Override at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=https://your-host/api/v1
```

## Architecture

- **MVVM**: `features/<area>/` screens + view models (`ChangeNotifier` + `provider`)
- **Core**: routing (`go_router`), theme, API client (`dio`), session, GST helpers, connectivity
- **Data**: models, `AppServices` (HTTP), local SQLite queue for offline POS invoices

## Linux desktop prerequisites (Ubuntu/Debian)

```bash
sudo apt install libsecret-1-dev lld-18 clang cmake ninja-build pkg-config libgtk-3-dev
```

`flutter_secure_storage` needs **libsecret**; the Dart Linux build looks for **ld.lld** in `/usr/lib/llvm-18/bin` (package **lld-18**).

If you see `Permission denied` copying to `/usr/local/mobile`, clear the Linux build cache and rebuild:

```bash
flutter clean
flutter run
```

## EMR (mobile MVP)

Screens under `/emr/*` (permission-gated, aligned with the Vue web app):

| Route | Screen |
|-------|--------|
| `/emr/appointments` | Today's patient appointments — confirm, cancel, start visit |
| `/emr/visits` | Visit list with status filters |
| `/emr/visits/new` | Create visit (`?appointment_id=` pre-fills from appointment) |
| `/emr/visits/:id` | Visit detail and bill-to-invoice |
| `/emr/visits/:id/edit` | Edit visit |
| `/emr/reminders` | Reminder dashboard and due list |

Users with the **doctor** role see a reduced menu (dashboard, customers, appointments, visits, reminders).

## Run

```bash
cd maran-billing-flutter-app
flutter pub get
flutter run
```

## Windows installer (Inno Setup)

Produces a single setup EXE that installs the Flutter Windows release bundle.

1. Install [Inno Setup 6](https://jrsoftware.org/isinfo.php) (include the Inno Setup Preprocessor).
2. From the project root:

```powershell
.\scripts\build-windows-installer.ps1
```

Options:

```powershell
.\scripts\build-windows-installer.ps1 -SkipBuild
.\scripts\build-windows-installer.ps1 -ApiBaseUrl https://api-maran.biapps.cloud/api/v1
.\scripts\build-windows-installer.ps1 -OutputDir D:\releases\maran
```

Output: `dist\windows\MaranBilling-Setup-<version>.exe`  
Script: `installer\maran_billing.iss`

## Windows auto-update (build + zip + upload)

One script builds the release, stages `Update.bat` / `Update.ps1`, zips the Release folder, and uploads it to the Laravel API.

1. On the server: migrate, `php artisan storage:link`, set `APP_UPDATE_DEPLOY_TOKEN` in `.env`.
2. On your PC (once):

```bat
setx MARAN_DEPLOY_TOKEN "same-secret-as-server"
```

3. Bump `version:` in `pubspec.yaml`, then:

```bat
.\scripts\build-zip-upload-update.bat
```

Options: `--skip-build`, `--mandatory`, `--notes "text"`.

Clients call `GET /api/v1/app/updates/check?platform=windows&current_build=N` on startup.

## Android auto-update (build + APK + upload)

Same Laravel API as Windows, with `platform=android` and an `.apk` package.

1. Server already has `APP_UPDATE_DEPLOY_TOKEN` and `php artisan storage:link`.
2. On your PC (once): `setx MARAN_DEPLOY_TOKEN "same-secret-as-server"`
3. Bump `version:` in `pubspec.yaml`, then:

```bat
.\scripts\build-apk-upload-update.bat
```

Options: `--skip-build`, `--mandatory`, `--notes "text"`.

Step-by-step: `scripts/ANDROID_AUTO_UPDATE_STEPS.txt`.

Android clients call `GET /api/v1/app/updates/check?platform=android&current_build=N` on startup, download the APK into app-private storage, then open the system installer.

## Tests

```bash
flutter test
flutter analyze
```

### Live API checks (optional)

Against [api-maran.biapps.cloud](https://api-maran.biapps.cloud/docs/api#/):

```bash
flutter test test/api_live_test.dart \
  --dart-define=API_TOKEN=your-sanctum-token \
  --dart-define=API_BASE_URL=https://api-maran.biapps.cloud/api/v1
```

Without `API_TOKEN`, live tests are skipped automatically.
