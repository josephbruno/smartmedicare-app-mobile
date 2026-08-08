# Sign Maran Billing Windows release binaries (Authenticode).
# Skips silently when signing credentials are not configured (unless -RequireSign).
# Auto-detects maran-billing-flutter-app\certs\maran-codesign.pfx when env is unset.
#Requires -Version 5.1
param(
  [string]$ReleaseDir = '',
  [string[]]$AdditionalFiles = @(),
  [switch]$FilesOnly,
  [switch]$RequireSign,
  [string]$PfxPath = $env:MARAN_SIGN_PFX_PATH,
  [string]$PfxPassword = $env:MARAN_SIGN_PFX_PASSWORD,
  [string]$TimestampUrl = $env:MARAN_SIGN_TIMESTAMP_URL,
  [string]$SignToolPath = $env:MARAN_SIGNTOOL_PATH,
  [string]$Description = 'Maran Billing'
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$ProjectRoot = (Resolve-Path (Join-Path $ScriptRoot '..')).Path
$DefaultPfx = Join-Path $ProjectRoot 'certs\maran-codesign.pfx'
$DefaultPasswordFile = Join-Path $ProjectRoot 'certs\maran-codesign.password'

if (-not $PfxPath -and (Test-Path -LiteralPath $DefaultPfx)) {
  $PfxPath = $DefaultPfx
  Write-Host "==> Using project cert: $PfxPath"
}
if (-not $PfxPassword -and (Test-Path -LiteralPath $DefaultPasswordFile)) {
  $PfxPassword = (Get-Content -LiteralPath $DefaultPasswordFile -Raw).Trim()
}

$SelfSigned = ($env:MARAN_SIGN_SELF_SIGNED -eq '1') -or (
  $PfxPath -and ($PfxPath -replace '\\', '/').ToLowerInvariant().Contains('/certs/maran-codesign.pfx')
)

if (-not $PfxPath) {
  $msg = @'
Code signing is not configured.

Option A — local self-signed (dev only, SmartScreen still warns on other PCs):
  powershell -File scripts\create-dev-codesign-cert.ps1

Option B — production CA cert:
  setx MARAN_SIGN_PFX_PATH "C:\certs\bestwave.pfx"
  setx MARAN_SIGN_PFX_PASSWORD "your-pfx-password"
  setx MARAN_SIGN_TIMESTAMP_URL "http://timestamp.digicert.com"
'@
  if ($RequireSign) {
    throw $msg
  }
  Write-Host '==> Code signing skipped (no MARAN_SIGN_PFX_PATH / certs\maran-codesign.pfx)'
  Write-Host '    Without a trusted CA cert, SmartScreen shows "Unknown publisher" on clinic PCs.'
  exit 0
}

if (-not $FilesOnly) {
  if (-not $ReleaseDir) {
    throw 'ReleaseDir is required unless -FilesOnly is used with -AdditionalFiles'
  }
  if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    throw "Release directory not found: $ReleaseDir"
  }
}
if (-not (Test-Path -LiteralPath $PfxPath)) {
  throw "PFX not found: $PfxPath"
}

if (-not $TimestampUrl) {
  $TimestampUrl = 'http://timestamp.digicert.com'
}

function Find-SignTool {
  param([string]$Explicit)
  if ($Explicit) {
    if (-not (Test-Path -LiteralPath $Explicit)) {
      throw "signtool.exe not found at: $Explicit"
    }
    return (Resolve-Path -LiteralPath $Explicit).Path
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

  throw @"
signtool.exe not found. Install Windows SDK or set MARAN_SIGNTOOL_PATH.

Example:
  setx MARAN_SIGNTOOL_PATH "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe"
"@
}

function Invoke-SignFile {
  param(
    [string]$SignToolExe,
    [string]$Target,
    [string]$Pfx,
    [string]$Password,
    [string]$Desc,
    [bool]$WithTimestamp,
    [string]$TsUrl
  )

  $signArgs = @(
    'sign',
    '/fd', 'SHA256',
    '/f', $Pfx,
    '/d', $Desc,
    '/du', 'https://bestwaveinnovation.com',
    '/v',
    $Target
  )
  if ($Password) {
    $signArgs = @(
      'sign',
      '/fd', 'SHA256',
      '/f', $Pfx,
      '/p', $Password,
      '/d', $Desc,
      '/du', 'https://bestwaveinnovation.com',
      '/v',
      $Target
    )
  }
  if ($WithTimestamp) {
    if ($Password) {
      $signArgs = @(
        'sign',
        '/fd', 'SHA256',
        '/f', $Pfx,
        '/p', $Password,
        '/tr', $TsUrl,
        '/td', 'SHA256',
        '/d', $Desc,
        '/du', 'https://bestwaveinnovation.com',
        '/v',
        $Target
      )
    } else {
      $signArgs = @(
        'sign',
        '/fd', 'SHA256',
        '/f', $Pfx,
        '/tr', $TsUrl,
        '/td', 'SHA256',
        '/d', $Desc,
        '/du', 'https://bestwaveinnovation.com',
        '/v',
        $Target
      )
    }
  }

  & $SignToolExe @signArgs
  return $LASTEXITCODE
}

$SignTool = Find-SignTool -Explicit $SignToolPath

$targets = @()
if (-not $FilesOnly -and $ReleaseDir) {
  $ReleaseResolved = (Resolve-Path -LiteralPath $ReleaseDir).Path
  $exe = Join-Path $ReleaseResolved 'mobile.exe'
  if (-not (Test-Path -LiteralPath $exe)) {
    throw "mobile.exe not found in $ReleaseResolved"
  }
  $targets += $exe
  $targets += @(
    Get-ChildItem -LiteralPath $ReleaseResolved -Filter '*.dll' -File |
      ForEach-Object { $_.FullName }
  )
}
$targets += @(
  $AdditionalFiles | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
)
$targets = @($targets | Select-Object -Unique)

if ($targets.Count -eq 0) {
  throw 'No files to sign'
}

Write-Host "==> Code signing $($targets.Count) file(s) with $PfxPath"
if ($SelfSigned) {
  Write-Host '    (self-signed / project cert — SmartScreen may still warn on other PCs)'
}

foreach ($file in $targets) {
  Write-Host "    signing $(Split-Path -Leaf $file)"
  $code = Invoke-SignFile -SignToolExe $SignTool -Target $file -Pfx $PfxPath `
    -Password $PfxPassword -Desc $Description -WithTimestamp:(-not $SelfSigned) -TsUrl $TimestampUrl
  if ($code -ne 0 -and -not $SelfSigned) {
    Write-Host '    timestamped sign failed; retrying without timestamp...'
    $code = Invoke-SignFile -SignToolExe $SignTool -Target $file -Pfx $PfxPath `
      -Password $PfxPassword -Desc $Description -WithTimestamp:$false -TsUrl $TimestampUrl
  }
  if ($code -ne 0) {
    throw "signtool failed for $file (exit $code)"
  }
  try { Unblock-File -LiteralPath $file -ErrorAction SilentlyContinue } catch {}
}

Write-Host '==> Code signing complete'
Write-Host '    Verify: right-click EXE -> Properties -> Digital Signatures'
