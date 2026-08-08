# Create a local (self-signed) Authenticode PFX for Maran Billing Windows builds.
# Stored under certs/ (gitignored). Does NOT fix SmartScreen for end users —
# use a CA-issued cert for production clinic distribution.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CertsDir = Join-Path $Root 'certs'
New-Item -ItemType Directory -Force -Path $CertsDir | Out-Null

$PfxPath = Join-Path $CertsDir 'maran-codesign.pfx'
$PasswordPath = Join-Path $CertsDir 'maran-codesign.password'
$EnvPs1Path = Join-Path $CertsDir 'load-signing-env.ps1'
$ReadmePath = Join-Path $CertsDir 'README.md'

# Stable-ish password for local reuse (also written to password file).
$plainPassword = -join (
  (48..57 + 65..90 + 97..122 | Get-Random -Count 24 | ForEach-Object { [char]$_ })
)
if (Test-Path -LiteralPath $PasswordPath) {
  $existing = (Get-Content -LiteralPath $PasswordPath -Raw).Trim()
  if ($existing) { $plainPassword = $existing }
}

$securePassword = ConvertTo-SecureString -String $plainPassword -Force -AsPlainText

Write-Host '==> Creating self-signed code signing certificate (CN=Bestwave Innovation)...'
$cert = New-SelfSignedCertificate `
  -Type CodeSigningCert `
  -Subject 'CN=Bestwave Innovation, O=Bestwave Innovation, C=IN' `
  -KeyAlgorithm RSA `
  -KeyLength 4096 `
  -HashAlgorithm SHA256 `
  -CertStoreLocation 'Cert:\CurrentUser\My' `
  -NotAfter (Get-Date).AddYears(5) `
  -KeyExportPolicy Exportable `
  -KeySpec Signature `
  -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')

Write-Host "    Thumbprint: $($cert.Thumbprint)"

if (Test-Path -LiteralPath $PfxPath) {
  Remove-Item -LiteralPath $PfxPath -Force
}

Export-PfxCertificate `
  -Cert $cert `
  -FilePath $PfxPath `
  -Password $securePassword | Out-Null

# Keep a copy of the public cert for documentation / trust install on test PCs.
$CerPath = Join-Path $CertsDir 'maran-codesign.cer'
Export-Certificate -Cert $cert -FilePath $CerPath -Type CERT | Out-Null

Set-Content -LiteralPath $PasswordPath -Value $plainPassword -Encoding ASCII -NoNewline

$envPs1 = @"
# Auto-generated — loads Maran local signing credentials into this PowerShell session.
# Dot-source before building:  . .\certs\load-signing-env.ps1
`$env:MARAN_SIGN_PFX_PATH = '$($PfxPath.Replace('\', '\\'))'
`$env:MARAN_SIGN_PFX_PASSWORD = Get-Content -LiteralPath '$($PasswordPath.Replace('\', '\\'))' -Raw
`$env:MARAN_SIGN_PFX_PASSWORD = `$env:MARAN_SIGN_PFX_PASSWORD.Trim()
`$env:MARAN_SIGN_TIMESTAMP_URL = 'http://timestamp.digicert.com'
`$env:MARAN_SIGN_SELF_SIGNED = '1'
Write-Host "Loaded signing env from certs\ (self-signed). SmartScreen may still warn on other PCs."
"@
Set-Content -LiteralPath $EnvPs1Path -Value $envPs1 -Encoding UTF8

$readme = @'
# Maran Windows code-signing (local)

This folder holds a **self-signed** code-signing certificate for local/dev builds.

## Files (secret — do not commit)

| File | Purpose |
|------|---------|
| `maran-codesign.pfx` | Private key + cert (signing) |
| `maran-codesign.password` | PFX password |
| `load-signing-env.ps1` | Sets `MARAN_SIGN_*` for the current shell |
| `maran-codesign.cer` | Public cert only (optional trust on test PCs) |

## Usage

```powershell
cd maran-billing-flutter-app
. .\certs\load-signing-env.ps1
cd scripts
.\build-single-exe.bat
.\build-zip-upload-update.bat
```

Build scripts also auto-detect `certs\maran-codesign.pfx` if env vars are unset.

## Important

- Self-signed signatures **do not** remove Windows SmartScreen "Unknown publisher" on clinic PCs.
- For production, replace this PFX with a **CA-issued** Authenticode certificate (DigiCert, Sectigo, etc.).
- Never commit `.pfx` / `.password` / `load-signing-env.ps1` to git.
'@
Set-Content -LiteralPath $ReadmePath -Value $readme -Encoding UTF8

Write-Host ''
Write-Host 'Done.'
Write-Host "  PFX:      $PfxPath"
Write-Host "  Password: $PasswordPath"
Write-Host "  Loader:   $EnvPs1Path"
Write-Host ''
Write-Host 'NOTE: Self-signed cert will NOT clear SmartScreen for other PCs.'
Write-Host '      Buy a real Authenticode cert for clinic production installs.'
