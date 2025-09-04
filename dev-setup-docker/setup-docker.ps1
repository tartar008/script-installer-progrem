#requires -Version 5.1
<#
.SYNOPSIS
  One-shot setup to enable WSL2, install (or upgrade) WSL core if missing, install Docker Desktop, and smoke-test docker.
  Run in **PowerShell as Administrator**.

.NOTES
  - Supports Windows 10/11. Reboots may be required.
  - Safe to re-run (idempotent): it skips steps already completed.
#>

[CmdletBinding()]
param(
  [switch]$EnableHyperV # optional; for Windows Pro/Enterprise only
)

$ErrorActionPreference = 'Stop'
$rebootRequired = $false

function Require-Admin {
  $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator. Right-click PowerShell and choose 'Run as administrator'."
  }
}

function Ensure-Feature {
  param([Parameter(Mandatory)][string]$Name)
  try {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $Name).State
    if ($state -ne 'Enabled') {
      Write-Host "Enabling Windows feature: $Name ..."
      Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart | Out-Null
      $script:rebootRequired = $true
    } else {
      Write-Host "Feature already enabled: $Name"
    }
  } catch {
    Write-Warning "Could not query/enable feature $Name. $_"
  }
}

function Ensure-WSLCore {
  <#
    Ensure the modern WSL package is installed (Store/MSIX). On some systems,
    calling 'wsl --version' returns an error indicating WSL is not installed.
    In that case, we invoke 'wsl --install --no-distribution' (if supported),
    falling back to plain 'wsl --install'. Both require a reboot.
  #>
  Write-Host "=== Ensure WSL core package is present ==="
  $needInstall = $false
  $versionOutput = ""
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "wsl.exe"
    $psi.Arguments = "--version"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    $versionOutput = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    if ($p.ExitCode -ne 0 -or $versionOutput -match "not installed") {
      $needInstall = $true
    }
  } catch {
    $needInstall = $true
  }

  if ($needInstall) {
    Write-Warning "WSL core not found. Installing WSL package from Microsoft (this will require a reboot)..."
    try {
      # Try no-distribution if available (Windows 11). If it fails, fallback.
      wsl.exe --install --no-distribution | Out-Null
    } catch {
      try {
        wsl.exe --install | Out-Null
      } catch {
        Write-Warning "Automatic WSL install failed. You can manually run: wsl --install"
        return
      }
    }
    $script:rebootRequired = $true
  } else {
    Write-Host "WSL core is present."
  }
}

function Add-UserToDockerGroup {
  try {
    if (-not (Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue)) {
      New-LocalGroup -Name 'docker-users' -Description 'Docker Desktop Users' | Out-Null
    }
    $currentUser = "$env:USERDOMAIN\$env:USERNAME"
    Add-LocalGroupMember -Group 'docker-users' -Member $currentUser -ErrorAction SilentlyContinue
    Write-Host "Ensured user '$currentUser' is in 'docker-users' group."
  } catch {
    Write-Warning "Could not add user to docker-users group. $_"
  }
}

Require-Admin

Write-Host "=== STEP 1/7: Enable required Windows features (WSL + VM Platform) ==="
Ensure-Feature -Name 'Microsoft-Windows-Subsystem-Linux'
Ensure-Feature -Name 'VirtualMachinePlatform'

if ($EnableHyperV) {
  Write-Host "Hyper-V flag provided; attempting to enable Hyper-V (optional)..."
  @(
    'Microsoft-Hyper-V-All',
    'Microsoft-Hyper-V',
    'Microsoft-Hyper-V-Tools-All',
    'Microsoft-Hyper-V-Management-PowerShell'
  ) | ForEach-Object { Ensure-Feature -Name $_ }
}

Write-Host "=== STEP 2/7: Ensure WSL core package exists (Store/MSIX) ==="
Ensure-WSLCore

Write-Host "=== STEP 3/7: Set WSL default version to 2 and update kernel ==="
try {
  wsl.exe --set-default-version 2 | Out-Null
  Write-Host "WSL default version set to 2."
} catch {
  Write-Warning "Could not set WSL default version. $_"
}
try {
  wsl.exe --update | Out-Null
  Write-Host "WSL kernel updated (or already up to date)."
} catch {
  Write-Warning "WSL kernel update skipped. $_"
}

Write-Host "=== STEP 4/7: (Optional) Ensure a Linux distro exists ==="
# If no distro registered, try to install Ubuntu-22.04 placeholder (user can remove later).
$distros = @()
try {
  $distros = (wsl.exe -l -q) 2>$null
} catch {}
if (-not $distros) { $distros = @() }
if ($distros.Count -eq 0) {
  Write-Host "No WSL distro found. Installing Ubuntu-22.04 (may require reboot + first-run user setup)..."
  try {
    wsl.exe --install -d Ubuntu-22.04 | Out-Null
    $script:rebootRequired = $true
  } catch {
    Write-Warning "Automatic distro install failed. You can install later with: wsl --install -d Ubuntu-22.04"
  }
} else {
  Write-Host "Detected WSL distro(s): $($distros -join ', ')"
}

Write-Host "=== STEP 5/7: Ensure winget exists ==="
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget (App Installer) not found. Install 'App Installer' from Microsoft Store, then re-run this script."
  exit 1
}

Write-Host "=== STEP 6/7: Install/Update Docker Desktop ==="
$dockerInstalled = $false
try {
  $list = (winget list --id Docker.DockerDesktop --source winget) 2>$null | Out-String
  if ($list -match 'Docker Desktop') { $dockerInstalled = $true }
} catch {}
if (-not $dockerInstalled) {
  Write-Host "Installing Docker Desktop via winget... (silent)"
  winget install --id Docker.DockerDesktop --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
} else {
  Write-Host "Docker Desktop appears to be installed. Attempting to upgrade if available..."
  winget upgrade --id Docker.DockerDesktop --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity | Out-Null
}

Write-Host "=== STEP 7/7: Add current user to 'docker-users' group and start Docker ==="
Add-UserToDockerGroup

if ($rebootRequired) {
  Write-Warning "A reboot is required to complete WSL/feature changes. Please reboot now, launch Docker Desktop once, then re-run this script to finish the smoke test."
  return
}

# Try to start Docker Desktop (non-blocking) and wait for engine readiness.
$dockerExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
if (Test-Path $dockerExe) {
  Write-Host "Starting Docker Desktop..."
  Start-Process -FilePath $dockerExe | Out-Null
}

Write-Host "Waiting for Docker Engine to become available (timeout 5 minutes)..."
$timeoutSec = 300
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$dockerReady = $false
while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
  try {
    docker version --format '{{.Server.Version}}' 2>$null | Out-Null
    $dockerReady = $true
    break
  } catch {
    Start-Sleep -Seconds 3
  }
}
$sw.Stop()

if ($dockerReady) {
  Write-Host "Docker is ready. Running a quick smoke test (hello-world)..."
  try {
    docker run --rm hello-world
    Write-Host "✅ Docker smoke test succeeded!"
  } catch {
    Write-Warning "Docker CLI found but hello-world failed to run. Open Docker Desktop and check Settings > Resources > WSL integration."
  }
} else {
  Write-Warning "Docker did not become ready in time. If you just installed/updated, please reboot and open Docker Desktop once, then try: docker run hello-world"
}

Write-Host "`nAll done. Re-run this script any time; completed steps will be skipped."
