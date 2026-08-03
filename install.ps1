# install.ps1 - ASCII-only installer for the kimiteam CLI bundle (GitHub Pages short link).
#
# Mirrors scripts/install-kimiteam.ps1 (Chinese) and scripts/install-kimiteam.sh (bash),
# but is ASCII-only so it is safe to run via: irm <url> | iex
# The repo keeps the Chinese .ps1 for the -File path.
#
# Downloads the latest kimiteam-dev rolling release and installs it alongside the
# official kimi CLI. The official kimi binary and lib/kimi/main.cjs are NEVER touched.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#   irm https://liewzheng.github.io/kimi-code/install.ps1 | iex
#
# Requires: node >= 24. Idempotent; re-running backs up the old bundle (upgrade).

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# RED LINE - NEVER touch the official kimi installation
# ---------------------------------------------------------------------------
# This script ONLY manages:
#   $HOME\.kimi-code\bin\kimiteam.ps1          (the team-build launcher)
#   $HOME\.kimi-code\lib\kimi\main-team.cjs    (the team-build CJS bundle)
#
# It MUST NOT read, write, or delete:
#   $HOME\.kimi-code\bin\kimi
#   $HOME\.kimi-code\lib\kimi\main.cjs
# ---------------------------------------------------------------------------

$Repo = 'Liewzheng/kimi-code'
$Release = 'kimiteam-dev'
$BaseUrl = "https://github.com/${Repo}/releases/download/${Release}"

$InstallDir = Join-Path $HOME '.kimi-code'
$LibDir = Join-Path $InstallDir 'lib\kimi'
$BinDir = Join-Path $InstallDir 'bin'

$BundleName = 'main-team.cjs'
$BundlePath = Join-Path $LibDir $BundleName
$Sha256File = 'main-team.cjs.sha256'
$LauncherPath = Join-Path $BinDir 'kimiteam.ps1'

# ---------------------------------------------------------------------------
# Pre-flight: node >= 24
# ---------------------------------------------------------------------------
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $nodeCmd) {
  Write-Host 'ERROR: node not found in PATH. Install Node.js >= 24 from https://nodejs.org/ or via your package manager.' -ForegroundColor Red
  exit 1
}

$nodeVersion = & node --version   # e.g. v24.15.0
$nodeMajor = 0
if ($nodeVersion -match '^v(\d+)') {
  $nodeMajor = [int]$Matches[1]
}
if ($nodeMajor -lt 24) {
  Write-Host "ERROR: Node.js ${nodeVersion} is too old. Need >= 24." -ForegroundColor Red
  Write-Host 'Please upgrade Node.js from https://nodejs.org/ or via your package manager.' -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------------------
# Create directories
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $LibDir, $BinDir | Out-Null

# ---------------------------------------------------------------------------
# Back up the existing bundle, if present
# ---------------------------------------------------------------------------
if (Test-Path -LiteralPath $BundlePath) {
  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backupName = "main-team.cjs.bak-${timestamp}"
  Copy-Item -LiteralPath $BundlePath -Destination (Join-Path $LibDir $backupName)
  Write-Host "Backed up existing bundle to $LibDir\$backupName"
}

# ---------------------------------------------------------------------------
# Download bundle + sha256
# ---------------------------------------------------------------------------
# Windows PowerShell 5.1 defaults to TLS 1.0/1.1; GitHub needs TLS 1.2+, so raise it first.
[Net.ServicePointManager]::SecurityProtocol = `
  [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

Write-Host "Downloading ${BundleName} from ${BaseUrl}/..."
Invoke-WebRequest -Uri "${BaseUrl}/${BundleName}" -OutFile $BundlePath -UseBasicParsing
Write-Host "Downloaded $BundlePath"

Write-Host "Downloading ${Sha256File}..."
Invoke-WebRequest -Uri "${BaseUrl}/${Sha256File}" -OutFile (Join-Path $LibDir $Sha256File) -UseBasicParsing

# ---------------------------------------------------------------------------
# Verify sha256
# ---------------------------------------------------------------------------
# The sha256 file contains one line like:
#   <hash>  apps/kimi-code/dist-native/intermediates/main.cjs
# Only the first whitespace-delimited token is the hash; verify actual bytes.
Write-Host 'Verifying sha256 checksum...'
$expectedHash = ((Get-Content -LiteralPath (Join-Path $LibDir $Sha256File) -TotalCount 1) -split '\s+')[0]
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $BundlePath).Hash
if ($expectedHash -ne $actualHash) {
  Write-Host 'ERROR: sha256 mismatch!' -ForegroundColor Red
  Write-Host "  Expected: ${expectedHash}" -ForegroundColor Red
  Write-Host "  Actual:   ${actualHash}" -ForegroundColor Red
  exit 1
}
Write-Host "sha256 checksum OK: ${actualHash}"

# ---------------------------------------------------------------------------
# Write launcher (ASCII-only, no BOM)
# ---------------------------------------------------------------------------
$launcherContent = @"
`$env:KIMI_CODE_EXPERIMENTAL_SECONDARY_MODEL = '1'
`$env:KIMI_CODE_EXPERIMENTAL_FLAG = '1'
& node "`$HOME\.kimi-code\lib\kimi\main-team.cjs" @args
"@
[System.IO.File]::WriteAllText($LauncherPath, $launcherContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Installed launcher: $LauncherPath"

# ---------------------------------------------------------------------------
# PATH reminder
# ---------------------------------------------------------------------------
if ($env:Path -split ';' -notcontains $BinDir) {
  $hint = '$env:Path += ";' + $BinDir + '"'
  Write-Host ''
  Write-Host "NOTE: $BinDir is not in your PATH."
  Write-Host 'Add it in PowerShell (or it takes effect on next login):'
  Write-Host "  $hint"
  Write-Host ''
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Installation complete. Verify with:'
Write-Host "  & $LauncherPath --version"
Write-Host "Or add $BinDir to PATH and run kimiteam directly."
