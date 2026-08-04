#Requires -Version 5.1
<#
.SYNOPSIS
  Maran Billing Windows in-place updater.
.DESCRIPTION
  Waits for the app process to exit, extracts a ZIP over the install directory,
  preserves user data patterns, cleans temp files, and relaunches the app.
#>
param(
  [Parameter(Mandatory = $true)][string]$ZipPath,
  [Parameter(Mandatory = $true)][string]$InstallDir,
  [Parameter(Mandatory = $true)][string]$ExeName,
  [Parameter(Mandatory = $true)][int]$WaitPid,
  [string]$Version = '',
  [switch]$ShowResult
)

$ErrorActionPreference = 'Stop'
$LogDir = Join-Path $env:LOCALAPPDATA 'MaranBilling\logs'
$ResultPath = Join-Path $env:TEMP 'maran_update_result.json'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir 'updater.log'

# Elevate when install dir is not writable (typical Program Files installs).
$needsAdmin = $false
try {
  $probe = Join-Path $InstallDir ('.maran_update_write_probe_' + [guid]::NewGuid().ToString('N'))
  [System.IO.File]::WriteAllText($probe, 'ok')
  Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
} catch {
  $needsAdmin = $true
}
if ($needsAdmin) {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
      '-ZipPath', "`"$ZipPath`""
      '-InstallDir', "`"$InstallDir`""
      '-ExeName', "`"$ExeName`""
      '-WaitPid', "$WaitPid"
      '-Version', "`"$Version`""
    )
    if ($ShowResult) { $argList += '-ShowResult' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList | Out-Null
    exit 0
  }
}

function Write-Log([string]$Message) {
  $line = '{0:u} {1}' -f (Get-Date).ToUniversalTime(), $Message
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Write-Result([bool]$Ok, [string]$Message) {
  $obj = @{
    ok      = $Ok
    version = $Version
    message = $Message
    at      = (Get-Date).ToUniversalTime().ToString('o')
  } | ConvertTo-Json -Compress
  Set-Content -LiteralPath $ResultPath -Value $obj -Encoding UTF8
}

function Test-PreserveRelativePath([string]$RelativePath) {
  $n = $RelativePath.Replace('\', '/').ToLowerInvariant()
  if ($n -match '(^|/)\.db$') { return $true }
  if ($n -match '(^|/)(config\.json|user_settings\.json)$') { return $true }
  if ($n -match '(^|/)(data/user|logs|updates)(/|$)') { return $true }
  if ($n -match '(^|/)update\.ps1$') { return $true }
  if ($n -match '(^|/)update\.bat$') { return $true }
  return $false
}

try {
  Write-Log "Start update version=$Version zip=$ZipPath install=$InstallDir waitPid=$WaitPid"

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "ZIP not found: $ZipPath"
  }
  if (-not (Test-Path -LiteralPath $InstallDir)) {
    throw "Install dir not found: $InstallDir"
  }

  $deadline = (Get-Date).AddSeconds(90)
  while ($true) {
    $proc = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
    if (-not $proc) { break }
    if ((Get-Date) -gt $deadline) {
      throw "Timed out waiting for process $WaitPid to exit"
    }
    Start-Sleep -Milliseconds 400
  }
  Write-Log "Process $WaitPid exited"

  # Extra safety: wait briefly for file locks to clear
  Start-Sleep -Seconds 1
  $exeBase = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
  $stillRunning = Get-Process -Name $exeBase -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase) }
  if ($stillRunning) {
    throw "Application process still running under install dir"
  }

  $extractRoot = Join-Path $env:TEMP ("maran_update_extract_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
  Write-Log "Extracting to $extractRoot"
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractRoot -Force

  # If ZIP contains a single top-level folder, use its contents
  $top = Get-ChildItem -LiteralPath $extractRoot | Where-Object { $_.Name -ne '__MACOSX' }
  $sourceRoot = $extractRoot
  if (@($top).Count -eq 1 -and $top[0].PSIsContainer) {
    $sourceRoot = $top[0].FullName
  }

  $exeInPackage = Join-Path $sourceRoot $ExeName
  if (-not (Test-Path -LiteralPath $exeInPackage)) {
    throw "Package missing executable: $ExeName"
  }

  Write-Log "Copying files into $InstallDir"
  Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
    if (Test-PreserveRelativePath $rel) {
      Write-Log "Preserve skip: $rel"
      return
    }
    $dest = Join-Path $InstallDir $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) {
      New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    $copied = $false
    for ($i = 0; $i -lt 8 -and -not $copied; $i++) {
      try {
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        $copied = $true
      } catch {
        Start-Sleep -Milliseconds 500
      }
    }
    if (-not $copied) {
      throw "Failed to copy: $rel"
    }
  }

  try { Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {}
  try { Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue } catch {}

  $launch = Join-Path $InstallDir $ExeName
  if (-not (Test-Path -LiteralPath $launch)) {
    throw "Updated executable missing: $launch"
  }

  Write-Log "Launching $launch"
  Start-Process -FilePath $launch -WorkingDirectory $InstallDir
  Write-Result -Ok $true -Message "Updated to $Version"
  Write-Log "Update succeeded"

  if ($ShowResult) {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
      "Maran Billing updated successfully to $Version.",
      'Update complete',
      'OK',
      'Information'
    ) | Out-Null
  }
  exit 0
} catch {
  $msg = $_.Exception.Message
  Write-Log "ERROR: $msg"
  Write-Result -Ok $false -Message $msg
  if ($ShowResult) {
    try {
      Add-Type -AssemblyName System.Windows.Forms | Out-Null
      [System.Windows.Forms.MessageBox]::Show(
        "Update failed:`n$msg",
        'Update failed',
        'OK',
        'Error'
      ) | Out-Null
    } catch {}
  }
  exit 1
}
