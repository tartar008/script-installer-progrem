#requires -Version 5.1
<#
.SYNOPSIS
  One-shot setup to enable WSL2, install Docker Desktop, and smoke-test `docker`.
  Run this in **PowerShell as Administrator**.

.NOTES
  - Works on Windows 10/11.
  - May request a reboot if features are newly enabled.
#>

[CmdletBinding()]
param(
  [switch]$EnableHyperV # optional; for Windows Pro/Enterprise only
)

$ErrorActionPreference = 'Stop'
$rebootRequired = $false

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

Write-Host "=== STEP 1/6: Enable required Windows features (WSL + VM Platform) ==="
Ensure-Feature -Name 'Microsoft-Windows-Subsystem-Linux'
Ensure-Feature -Name 'VirtualMachinePlatform'

if ($EnableHyperV) {
  # Hyper-V is optional (Pro/Enterprise). Docker Desktop on Home uses WSL2 backend without Hyper-V.
  Write-Host "Hyper-V flag provided; attempting to enable Hyper-V (optional)..."
  @(
    'Microsoft-Hyper-V-All',
    'Microsoft-Hyper-V',
    'Microsoft-Hyper-V-Tools-All',
    'Microsoft-Hyper-V-Management-PowerShell'
  ) | ForEach-Object { Ensure-Feature -Name $_ }
}

Write-Host "=== STEP 2/6: Set WSL default version to 2 and update kernel ==="
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

Write-Host "=== STEP 3/6: (Optional) Ensure a Linux distro exists ==="
# We prefer Ubuntu-22.04 if none exists; creating a distro may require a reboot & user setup.
$distros = (wsl.exe -l -q) 2>$null
if (-not $distros) { $distros = @() }
if ($distros.Count -eq 0) {
  Write-Host "No WSL distro found. Installing Ubuntu-22.04 placeholder (may require reboot + Linux user setup)..."
  try {
    wsl.exe --install -d Ubuntu-22.04 | Out-Null
    $script:rebootRequired = $true
  } catch {
    Write-Warning "Automatic distro install failed. You can install later with: wsl --install -d Ubuntu-22.04"
  }
} else {
  Write-Host "Detected WSL distro(s): $($distros -join ', ')"
}

Write-Host "=== STEP 4/6: Ensure winget exists ==="
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget (App Installer) not found. Install 'App Installer' from Microsoft Store, then re-run this script."
  exit 1
}

Write-Host "=== STEP 5/6: Install/Update Docker Desktop ==="
# Try to detect if Docker Desktop is already installed
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

Write-Host "=== STEP 6/6: Add current user to 'docker-users' group and start Docker ==="
# Ensure local group exists, then add current user
try {
  if (-not (Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name 'docker-users' -Description 'Docker Desktop Users' | Out-Null
  }
  $currentUser = "$env:USERDOMAIN\$env:USERNAME"
  Add-LocalGroupMember -Group 'docker-users' -Member $currentUser -ErrorAction SilentlyContinue
  Write-Host "Ensured user '$currentUser' is in 'docker-users' group."
} catch {
  Write-Warning "Could not add user to docker-users group. You may need to do this manually in Computer Management."
}

# If a reboot was requested earlier, advise and exit early to avoid false negatives
if ($rebootRequired) {
  Write-Warning "A reboot is required to complete WSL/feature changes. Please reboot, launch Docker Desktop once, then re-run the smoke test section of this script."
  Write-Host "You can rerun only the test by executing:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -TestOnly"
}

# Try to start Docker Desktop (non-blocking). If installed to default path:
$dockerExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
if (Test-Path $dockerExe) {
  Write-Host "Starting Docker Desktop..."
  Start-Process -FilePath $dockerExe | Out-Null
} else {
  Write-Warning "Docker Desktop launcher not found at default path. Start it from Start Menu manually after reboot."
}

# Wait until `docker` CLI is available
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
  Write-Warning "Docker did not become ready in time. If you just installed/updated, please reboot and open Docker Desktop once."
}

Write-Host "`nAll done. If you were prompted to reboot, please do so and then re-run the test section (docker run hello-world)."
