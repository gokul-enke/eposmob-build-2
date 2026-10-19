<#
.SYNOPSIS
  Builds one brand of the Windows app and its installer.

.DESCRIPTION
  Reads brands/<Brand>/brand.json and passes it to every layer that shows the
  brand: CMake (window title, icon, exe version info, single-instance lock),
  Dart (--dart-define-from-file) and Inno Setup (name, AppId, exe name, data
  folder). Release CI runs this once per brand; run it locally the same way.

.EXAMPLE
  ./scripts/build_brand.ps1 -Brand easyerp
#>
[CmdletBinding()]
param(
  [string]$Brand = "cloudpos",
  [string]$BaseUrl = "https://eeezeeerp.cloudposai.com",
  # Defaults to the pubspec version with "+" replaced by ".".
  [string]$Version,
  [string]$IsccPath,
  # Package an existing build/windows output without rebuilding it.
  [switch]$SkipBuild,
  [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Invoke-Checked([string]$Description, [scriptblock]$Command) {
  Write-Host "==> $Description" -ForegroundColor Cyan
  # Windows PowerShell 5.1 turns any native stderr line (CMake warnings) into
  # a terminating error under "Stop" when output is redirected. Judge native
  # tools by their exit code only.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & $Command } finally { $ErrorActionPreference = $previous }
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE."
  }
}

# --- Brand -------------------------------------------------------------------
$brandFile = Join-Path $projectRoot "brands/$Brand/brand.json"
if (-not (Test-Path $brandFile)) {
  $known = (Get-ChildItem (Join-Path $projectRoot "brands") -Directory).Name -join ", "
  throw "Unknown brand '$Brand'. Known brands: $known"
}
$config = Get-Content $brandFile -Raw | ConvertFrom-Json
$required = "BRAND_ID", "BRAND_NAME", "BRAND_TITLE", "BRAND_COMPANY",
  "BRAND_PRODUCT_NAME", "BRAND_PUBLISHER", "BRAND_URL", "BRAND_EXE_NAME",
  "BRAND_INSTALLER_NAME", "BRAND_APP_ID", "BRAND_LOGO_ASSET", "BRAND_ICON_ASSET"
foreach ($key in $required) {
  $value = $config.PSObject.Properties[$key]
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value.Value)) {
    throw "$brandFile is missing $key."
  }
  if ([string]$value.Value -match '[^\x20-\x7E]|"') {
    throw "$key in $brandFile must be plain ASCII without quotes (it is compiled into Runner.rc)."
  }
}
if ($config.BRAND_ID -ne $Brand) {
  throw "BRAND_ID '$($config.BRAND_ID)' in $brandFile must match its folder name '$Brand'."
}
if ($config.BRAND_APP_ID -notmatch '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') {
  throw "BRAND_APP_ID must be a bare GUID (no braces)."
}
foreach ($asset in $config.BRAND_LOGO_ASSET, $config.BRAND_ICON_ASSET) {
  if (-not (Test-Path (Join-Path $projectRoot $asset))) {
    throw "Asset $asset from $brandFile does not exist."
  }
}
# Two brands sharing an id or data folder would overwrite each other's install.
foreach ($other in Get-ChildItem (Join-Path $projectRoot "brands") -Directory) {
  if ($other.Name -eq $Brand) { continue }
  $otherFile = Join-Path $other.FullName "brand.json"
  if (-not (Test-Path $otherFile)) { continue }
  $o = Get-Content $otherFile -Raw | ConvertFrom-Json
  if ($o.BRAND_APP_ID -eq $config.BRAND_APP_ID) { throw "BRAND_APP_ID is also used by brand '$($other.Name)'." }
  if ("$($o.BRAND_COMPANY)\$($o.BRAND_PRODUCT_NAME)" -eq "$($config.BRAND_COMPANY)\$($config.BRAND_PRODUCT_NAME)") {
    throw "BRAND_COMPANY/BRAND_PRODUCT_NAME (data folder) is also used by brand '$($other.Name)'."
  }
}

if (-not $Version) {
  $line = Get-Content (Join-Path $projectRoot "pubspec.yaml") |
    Where-Object { $_ -match '^version:\s+\S+' } | Select-Object -First 1
  $pubspecVersion = ($line -replace '^version:\s*', '').Trim()
  if ($pubspecVersion -notmatch '^\d+\.\d+\.\d+(\+\d+)?$') {
    throw "Unsupported pubspec version: $pubspecVersion"
  }
  $Version = $pubspecVersion.Replace('+', '.')
}

Write-Host "Brand $Brand ($($config.BRAND_TITLE)), version $Version" -ForegroundColor Green

# --- Build -------------------------------------------------------------------
$releaseDir = Join-Path $projectRoot "build/windows/x64/runner/Release"
$exePath = Join-Path $releaseDir "cloudpos.exe"
if (-not $SkipBuild) {
  # Read by windows/runner/CMakeLists.txt.
  $env:CLOUDPOS_BRAND = $Brand
  try {
    Invoke-Checked "Building Windows release for $Brand" {
      flutter build windows --release "--dart-define=BASE_URL=$BaseUrl" "--dart-define-from-file=$brandFile"
    }
  } finally {
    Remove-Item Env:CLOUDPOS_BRAND -ErrorAction SilentlyContinue
  }
}
if (-not (Test-Path $exePath)) {
  throw "Missing $exePath. Build first or drop -SkipBuild."
}

# The exe's version info decides the data folder, so a stale or wrong-brand
# build must never be packaged.
$info = (Get-Item $exePath).VersionInfo
if ($info.ProductName -ne $config.BRAND_PRODUCT_NAME -or $info.CompanyName -ne $config.BRAND_COMPANY) {
  throw "Built exe is '$($info.CompanyName)\$($info.ProductName)', expected '$($config.BRAND_COMPANY)\$($config.BRAND_PRODUCT_NAME)'. Rebuild without -SkipBuild."
}
Write-Host "Exe brand check OK: $($info.FileDescription), data folder $($info.CompanyName)\$($info.ProductName)"

if ($SkipInstaller) { return }

# --- Installer ---------------------------------------------------------------
if (-not (Test-Path (Join-Path $projectRoot "installer-assets/vc_redist.x64.exe"))) {
  throw "installer-assets/vc_redist.x64.exe is missing. Download it from https://aka.ms/vc14/vc_redist.x64.exe."
}
if (-not $IsccPath) {
  $IsccPath = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $IsccPath) {
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) { $IsccPath = $cmd.Source }
  }
}
if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
  throw "Inno Setup (ISCC.exe) not found. Install Inno Setup 6 or pass -IsccPath."
}

$brandIcon = Join-Path $projectRoot "brands/$Brand/app_icon.ico"
$icon = if (Test-Path $brandIcon) { $brandIcon } else { Join-Path $projectRoot "windows/runner/resources/app_icon.ico" }
$installer = Join-Path $projectRoot "Output/$($config.BRAND_INSTALLER_NAME)-$Version.exe"
if (Test-Path $installer) { Remove-Item $installer -Force }

Invoke-Checked "Building installer for $Brand" {
  & $IsccPath `
    "/DMyAppVersion=$Version" `
    "/DMyAppName=$($config.BRAND_TITLE)" `
    "/DMyAppId=$($config.BRAND_APP_ID)" `
    "/DMyAppExeName=$($config.BRAND_EXE_NAME)" `
    "/DMyInstallerName=$($config.BRAND_INSTALLER_NAME)" `
    "/DMyAppIcon=$icon" `
    "/DMyDataDir=$($config.BRAND_COMPANY)\$($config.BRAND_PRODUCT_NAME)" `
    "/DMyAppPublisher=$($config.BRAND_PUBLISHER)" `
    "/DMyAppURL=$($config.BRAND_URL)" `
    (Join-Path $projectRoot "inno_setup.iss")
}
if (-not (Test-Path $installer)) {
  throw "Expected installer $installer was not created."
}
Write-Host "Created $installer" -ForegroundColor Green
if ($env:GITHUB_OUTPUT) {
  # Relative with forward slashes: action-gh-release treats `files` as globs.
  "installer=Output/$($config.BRAND_INSTALLER_NAME)-$Version.exe" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
