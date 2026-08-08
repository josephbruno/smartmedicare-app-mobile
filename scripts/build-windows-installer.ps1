# Build Maran Billing Windows release and package as an Inno Setup installer (.exe).
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

$AppName = 'Maran Billing'
$BinaryName = 'mobile.exe'
$SkipBuild = $false
$RequireSign = $false
$OutputDir = Join-Path $Root 'dist\windows'
$ApiBaseUrl = $null
$IsccPath = $null

function Show-Usage {
  @"
Usage: $($MyInvocation.MyCommand.Name) [options]

Build the Flutter Windows release bundle and create an Inno Setup installer.

Options:
  -SkipBuild              Skip 'flutter build windows --release' (reuse existing bundle)
  -RequireSign            Fail if MARAN_SIGN_PFX_PATH is not set (recommended for clinic releases)
  -OutputDir DIR          Output directory for installer (default: dist\windows)
  -ApiBaseUrl URL         Pass --dart-define=API_BASE_URL=URL to flutter build
  -IsccPath PATH          Path to ISCC.exe (auto-detected if omitted)
  -Help                   Show this help
"@
}

for ($i = 0; $i -lt $args.Count; $i++) {
  switch -Regex ($args[$i]) {
    '^(?i)-SkipBuild$' { $SkipBuild = $true }
    '^(?i)-RequireSign$' { $RequireSign = $true }
    '^(?i)-OutputDir$' {
      $i++
      if ($i -ge $args.Count) { throw 'Missing value for -OutputDir' }
      $OutputDir = $args[$i]
    }
    '^(?i)-ApiBaseUrl$' {
      $i++
      if ($i -ge $args.Count) { throw 'Missing value for -ApiBaseUrl' }
      $ApiBaseUrl = $args[$i]
    }
    '^(?i)-IsccPath$' {
      $i++
      if ($i -ge $args.Count) { throw 'Missing value for -IsccPath' }
      $IsccPath = $args[$i]
    }
    '^(?i)-Help$|^/\?$' { Show-Usage; exit 0 }
    default { throw "Unknown option: $($args[$i])`n$(Show-Usage)" }
  }
}

function Find-Iscc {
  param([string]$Explicit)
  if ($Explicit) {
    if (-not (Test-Path -LiteralPath $Explicit)) {
      throw "ISCC.exe not found at: $Explicit"
    }
    return (Resolve-Path -LiteralPath $Explicit).Path
  }

  $candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe"
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }

  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  throw @"
Inno Setup compiler (ISCC.exe) not found.

Install Inno Setup 6 from https://jrsoftware.org/isinfo.php
(enable Inno Setup Preprocessor), then re-run this script.
Or pass -IsccPath "C:\Path\To\ISCC.exe"
"@
}

function Find-SignTool {
  if ($env:MARAN_SIGNTOOL_PATH -and (Test-Path -LiteralPath $env:MARAN_SIGNTOOL_PATH)) {
    return (Resolve-Path -LiteralPath $env:MARAN_SIGNTOOL_PATH).Path
  }
  $kits = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
    "${env:ProgramFiles}\Windows Kits\10\bin\*\x64\signtool.exe"
  )
  foreach ($pattern in $kits) {
    $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
      Sort-Object { $_.FullName } -Descending |
      Select-Object -First 1
    if ($found) { return $found.FullName }
  }
  $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'flutter not found in PATH'
}

$Iscc = Find-Iscc -Explicit $IsccPath
$SignScript = Join-Path $PSScriptRoot 'sign-windows-release.ps1'
$ProjectPfx = Join-Path $Root 'certs\maran-codesign.pfx'
$ProjectPasswordFile = Join-Path $Root 'certs\maran-codesign.password'
$HasPfx = [bool]$env:MARAN_SIGN_PFX_PATH -or (Test-Path -LiteralPath $ProjectPfx)
$MustSign = $RequireSign -or ($env:MARAN_REQUIRE_SIGN -eq '1')

if ($MustSign -and -not $HasPfx) {
  throw @"
-RequireSign was set but no signing certificate was found.

Create a local cert:
  powershell -File scripts\create-dev-codesign-cert.ps1

Or set a CA-issued PFX:
  setx MARAN_SIGN_PFX_PATH "C:\certs\bestwave.pfx"
  setx MARAN_SIGN_PFX_PASSWORD "your-pfx-password"

Open a NEW terminal and rebuild.
"@
}

$VersionLine = (Select-String -Path (Join-Path $Root 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
$Version = ($VersionLine -split '\+')[0]
$BuildNum = if ($VersionLine -match '\+(.+)$') { $Matches[1] } else { '1' }

$ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
$ExePath = Join-Path $ReleaseDir $BinaryName
$IssPath = Join-Path $Root 'installer\maran_billing.iss'

if (-not (Test-Path -LiteralPath $IssPath)) {
  throw "Inno script not found: $IssPath"
}

if (-not $SkipBuild) {
  Write-Host "==> Building Flutter Windows release..."
  $buildArgs = @('build', 'windows', '--release')
  if ($ApiBaseUrl) {
    $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
  }
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path -LiteralPath $ExePath)) {
  throw @"
Release bundle not found at $ExePath
Run without -SkipBuild or fix the Flutter build.
"@
}

Write-Host '==> Signing release binaries...'
$signParams = @{ ReleaseDir = $ReleaseDir }
if ($MustSign) { $signParams['RequireSign'] = $true }
& $SignScript @signParams
if ($LASTEXITCODE -ne 0) { throw 'Code signing failed' }

$UpdaterDir = Join-Path $Root 'updater'
foreach ($name in @('Update.bat', 'Update.ps1')) {
  $src = Join-Path $UpdaterDir $name
  if (-not (Test-Path -LiteralPath $src)) {
    throw "Updater script missing: $src"
  }
  Copy-Item -LiteralPath $src -Destination (Join-Path $ReleaseDir $name) -Force
  try { Unblock-File -LiteralPath (Join-Path $ReleaseDir $name) -ErrorAction SilentlyContinue } catch {}
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDirResolved = (Resolve-Path -LiteralPath $OutputDir).Path
$ReleaseDirResolved = (Resolve-Path -LiteralPath $ReleaseDir).Path
# Inno preprocessor is happier with forward slashes in /D path defines.
$ReleaseDirInno = $ReleaseDirResolved.Replace('\', '/')
$OutputDirInno = $OutputDirResolved.Replace('\', '/')

$isccArgs = @(
  "/DMyAppVersion=$Version"
  "/DMyAppName=$AppName"
  "/DMyAppExeName=$BinaryName"
  "/DFlutterReleaseDir=$ReleaseDirInno"
  "/DOutputDir=$OutputDirInno"
)

# Sign setup EXE after compile when a PFX is available (env or project certs/).
# (Inno SignTool path is skipped here to avoid fragile quoting; post-sign is reliable.)
Write-Host "==> Compiling Inno Setup installer (v$Version+$BuildNum)..."
& $Iscc @isccArgs $IssPath

if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

$Installer = Join-Path $OutputDirResolved "MaranBilling-Setup-$Version.exe"
if (-not (Test-Path -LiteralPath $Installer)) {
  throw "Expected installer not found: $Installer"
}

if ($HasPfx) {
  Write-Host '==> Signing setup EXE...'
  & $SignScript -FilesOnly -AdditionalFiles @($Installer) -Description 'Maran Billing Setup'
  if ($LASTEXITCODE -ne 0) { throw 'Installer code signing failed' }
}

try { Unblock-File -LiteralPath $Installer -ErrorAction SilentlyContinue } catch {}

Write-Host ''
Write-Host 'Done.'
Write-Host "  Installer: $Installer"
Write-Host "  App:       $AppName ($BinaryName)"
if (-not $HasPfx) {
  Write-Host ''
  Write-Host 'WARNING: Installer is UNSIGNED.'
  Write-Host '  Windows SmartScreen will show "Unknown publisher" on clinic PCs.'
  Write-Host '  Fix: set MARAN_SIGN_PFX_PATH / MARAN_SIGN_PFX_PASSWORD, then rebuild.'
  Write-Host '  Temporary: More info -> Run anyway'
} else {
  Write-Host '  Signed:    yes (Authenticode)'
  Write-Host '  Verify:    Properties -> Digital Signatures'
}
