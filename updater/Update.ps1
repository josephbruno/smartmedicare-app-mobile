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

function Write-Log([string]$Message) {
  try {
    $line = '{0:u} {1}' -f (Get-Date).ToUniversalTime(), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  } catch {}
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

function Show-UpdateMessage([string]$Title, [string]$Message, [string]$Icon) {
  # Prefer WinForms; fall back to WScript popup so users always see a result.
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $boxIcon = if ($Icon -eq 'Error') { 'Error' } else { 'Information' }
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', $boxIcon) | Out-Null
    return
  } catch {}
  try {
    $wicon = if ($Icon -eq 'Error') { 16 } else { 64 }
    (New-Object -ComObject WScript.Shell).Popup($Message, 0, $Title, $wicon) | Out-Null
  } catch {}
}

Write-Log "Updater process started pid=$PID showResult=$ShowResult"

function Test-PreserveRelativePath([string]$RelativePath) {
  $n = $RelativePath.Replace('\', '/').ToLowerInvariant()
  if ($n -match '\.db$') { return $true }
  if ($n -match '(^|/)(config\.json|user_settings\.json)$') { return $true }
  if ($n -match '(^|/)(data/user|logs|updates)(/|$)') { return $true }
  return $false
}

function Test-DirectoryWritable([string]$Dir) {
  try {
    $probe = Join-Path $Dir ('.maran_update_write_probe_' + [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($probe, 'ok')
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    return $true
  } catch {
    return $false
  }
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Elevate early when install dir is not writable (Program Files).
if (-not (Test-DirectoryWritable -Dir $InstallDir)) {
  if (-not (Test-IsAdmin)) {
    try { Write-Log "Install dir not writable; requesting elevation. install=$InstallDir" } catch {}
    # Copy this script to TEMP so elevation does not depend on Program Files ACLs.
    $tempPs1 = Join-Path $env:TEMP ("MaranUpdate_" + [guid]::NewGuid().ToString('N') + '.ps1')
    Copy-Item -LiteralPath $PSCommandPath -Destination $tempPs1 -Force

    $show = if ($ShowResult) { ' -ShowResult' } else { '' }
    # Single argument string — required for paths with spaces (Program Files\...).
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$tempPs1`" -ZipPath `"$ZipPath`" -InstallDir `"$InstallDir`" -ExeName `"$ExeName`" -WaitPid $WaitPid -Version `"$Version`"$show"
    try {
      Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arg | Out-Null
      exit 0
    } catch {
      $msg = 'Administrator approval is required to update Maran Billing under Program Files. Click Yes on the UAC prompt, then try Update again.'
      try { Write-Log "ERROR: elevation failed: $($_.Exception.Message)" } catch {}
      Write-Result -Ok $false -Message $msg
      try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        [System.Windows.Forms.MessageBox]::Show($msg, 'Update failed', 'OK', 'Error') | Out-Null
      } catch {}
      exit 1
    }
  }
}

try {
  Write-Log "Start update version=$Version zip=$ZipPath install=$InstallDir waitPid=$WaitPid admin=$(Test-IsAdmin)"

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "ZIP not found: $ZipPath"
  }
  if (-not (Test-Path -LiteralPath $InstallDir)) {
    throw "Install dir not found: $InstallDir"
  }
  if (-not (Test-DirectoryWritable -Dir $InstallDir)) {
    throw "Install dir is not writable even after elevation: $InstallDir"
  }

  if ($WaitPid -gt 0) {
    $deadline = (Get-Date).AddSeconds(120)
    while ($true) {
      $proc = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
      if (-not $proc) { break }
      if ((Get-Date) -gt $deadline) {
        throw "Timed out waiting for process $WaitPid to exit"
      }
      Start-Sleep -Milliseconds 400
    }
    Write-Log "Process $WaitPid exited"
  } else {
    Write-Log "WaitPid=$WaitPid - skip process wait"
  }

  # Extra safety: wait for file locks / leftover app instances in this install dir.
  Start-Sleep -Seconds 2
  $exeBase = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
  $deadline = (Get-Date).AddSeconds(60)
  while ($true) {
    $stillRunning = @(Get-Process -Name $exeBase -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Path -and $_.Path.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase)
      })
    if ($stillRunning.Count -eq 0) { break }
    if ((Get-Date) -gt $deadline) {
      throw "Application process still running under install dir"
    }
    Start-Sleep -Milliseconds 500
  }

  $extractRoot = Join-Path $env:TEMP ("maran_update_extract_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
  Write-Log "Extracting to $extractRoot"
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractRoot -Force

  $top = @(Get-ChildItem -LiteralPath $extractRoot | Where-Object { $_.Name -ne '__MACOSX' })
  $sourceRoot = $extractRoot
  if ($top.Count -eq 1 -and $top[0].PSIsContainer) {
    $sourceRoot = $top[0].FullName
  }

  $exeInPackage = Join-Path $sourceRoot $ExeName
  if (-not (Test-Path -LiteralPath $exeInPackage)) {
    throw "Package missing executable: $ExeName"
  }

  Write-Log "Copying files into $InstallDir"
  $files = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File
  foreach ($file in $files) {
    $rel = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
    if (Test-PreserveRelativePath $rel) {
      Write-Log "Preserve skip: $rel"
      continue
    }
    $dest = Join-Path $InstallDir $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) {
      New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    $copied = $false
    for ($i = 0; $i -lt 10 -and -not $copied; $i++) {
      try {
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
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

  $afterVer = (Get-Item -LiteralPath $launch).VersionInfo.FileVersion
  Write-Log "Launching $launch (FileVersion=$afterVer)"
  if ($Version -and $afterVer -and ($afterVer -notlike "*$Version*")) {
    throw "Update copied files but version mismatch. Expected $Version, got $afterVer"
  }
  Start-Process -FilePath $launch -WorkingDirectory $InstallDir
  Write-Result -Ok $true -Message "Updated to $Version ($afterVer)"
  Write-Log "Update succeeded"

  if ($ShowResult) {
    Show-UpdateMessage -Title 'Update complete' -Message "Maran Billing updated successfully to $Version." -Icon 'Info'
  }
  exit 0
} catch {
  $msg = $_.Exception.Message
  Write-Log "ERROR: $msg"
  Write-Result -Ok $false -Message $msg
  if ($ShowResult) {
    Show-UpdateMessage -Title 'Update failed' -Message ("Update failed:" + [Environment]::NewLine + $msg) -Icon 'Error'
  }
  # Relaunch old app so the user is not left with nothing open.
  try {
    $launch = Join-Path $InstallDir $ExeName
    if (Test-Path -LiteralPath $launch) {
      Start-Process -FilePath $launch -WorkingDirectory $InstallDir
    }
  } catch {}
  exit 1
}
