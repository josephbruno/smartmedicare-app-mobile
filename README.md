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
