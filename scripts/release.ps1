[CmdletBinding()]
param(
  [string]$ConfigPath = "local-release/release.config.psd1",
  [switch]$SkipGooglePlay,
  [switch]$SkipMicrosoftStore,
  [switch]$SkipGoogleDrive,
  [switch]$SkipClean,
  [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Assert-Command([string]$Name, [string]$InstallHint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "'$Name' was not found on PATH. $InstallHint"
  }
}

function Invoke-Checked([string]$Description, [scriptblock]$Command) {
  Write-Host "==> $Description" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE."
  }
}

function Get-RequiredValue([object]$Value, [string]$Name) {
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    throw "Missing $Name. Set it in $ConfigPath or the documented environment variable."
  }
  return [string]$Value
}

function Get-ConfigOrEnvironmentValue([hashtable]$Section, [string]$Key, [string]$EnvironmentName) {
  if ($Section.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$Section[$Key])) {
    return [string]$Section[$Key]
  }
  return [string][Environment]::GetEnvironmentVariable($EnvironmentName)
}

$resolvedConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath
} else {
  Join-Path $projectRoot $ConfigPath
}
if (-not (Test-Path -LiteralPath $resolvedConfigPath)) {
  throw "Release configuration not found: $resolvedConfigPath. Copy local-release/release.config.example.psd1 to local-release/release.config.psd1 and fill it in."
}
$config = Import-PowerShellDataFile -LiteralPath $resolvedConfigPath

foreach ($sectionName in @("GooglePlay", "MicrosoftStore", "GoogleDrive")) {
  if (-not $config.ContainsKey($sectionName)) {
    throw "Missing '$sectionName' section in $resolvedConfigPath."
  }
}

$baseUrl = Get-RequiredValue $config.BaseUrl "BaseUrl"
$versionLine = Get-Content "pubspec.yaml" | Where-Object { $_ -match '^version:\s+(\S+)' } | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s+(\d+\.\d+\.\d+)(\+(\d+))?$') {
  throw "pubspec.yaml must contain a version in the form x.y.z+build."
}
$releaseVersion = $Matches[1]
$buildNumber = $Matches[3]
if (-not $buildNumber) { throw "A Play Store release requires a numeric build number in pubspec.yaml (for example: 1.2.3+45)." }

$artifactDirectory = Join-Path $projectRoot "local-release/output/$releaseVersion+$buildNumber"
if (Test-Path -LiteralPath $artifactDirectory) {
  Remove-Item -LiteralPath $artifactDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null

Assert-Command "flutter" "Install Flutter and reopen PowerShell."
if (-not $SkipClean) {
  Invoke-Checked "Cleaning Flutter outputs" { flutter clean }
}
Invoke-Checked "Getting Flutter packages" { flutter pub get }

$builtArtifacts = [System.Collections.Generic.List[string]]::new()

if (-not $SkipGooglePlay) {
  Assert-Command "fastlane" "Install Ruby and run: gem install fastlane"
  if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "android/key.properties"))) {
    throw "android/key.properties is required for a signed Google Play bundle. See docs/LOCAL_RELEASE.md."
  }
  $play = $config.GooglePlay
  $packageName = Get-RequiredValue $play.PackageName "GooglePlay.PackageName"
  $track = Get-RequiredValue $play.Track "GooglePlay.Track"
  $serviceAccountJson = Get-ConfigOrEnvironmentValue $play "ServiceAccountJson" "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
  $serviceAccountJson = Get-RequiredValue $serviceAccountJson "GooglePlay.ServiceAccountJson / GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
  if (-not (Test-Path -LiteralPath $serviceAccountJson)) { throw "Google Play service-account JSON was not found: $serviceAccountJson" }

  Invoke-Checked "Building signed Android app bundle" { flutter build appbundle --release "--dart-define=BASE_URL=$baseUrl" }
  $aab = Join-Path $projectRoot "build/app/outputs/bundle/release/app-release.aab"
  if (-not (Test-Path -LiteralPath $aab)) { throw "Flutter did not create an Android App Bundle at $aab" }
  $stagedAab = Join-Path $artifactDirectory "cloudpos-$releaseVersion+$buildNumber.aab"
  Copy-Item -LiteralPath $aab -Destination $stagedAab -Force
  $builtArtifacts.Add($stagedAab)

  $releaseStatus = if ($play.ContainsKey("ReleaseStatus")) { [string]$play.ReleaseStatus } else { "completed" }
  Invoke-Checked "Publishing Android bundle to Google Play ($track)" {
    fastlane supply --aab $stagedAab --json_key $serviceAccountJson --package_name $packageName --track $track --release_status $releaseStatus --skip_upload_metadata true --skip_upload_images true --skip_upload_screenshots true
  }
}

if (-not $SkipMicrosoftStore) {
  Assert-Command "msstore" "Install it with: winget install Microsoft.MSStoreCLI"
  $store = $config.MicrosoftStore
  $tenantId = Get-RequiredValue (Get-ConfigOrEnvironmentValue $store "TenantId" "MS_STORE_TENANT_ID") "MicrosoftStore.TenantId / MS_STORE_TENANT_ID"
  $clientId = Get-RequiredValue (Get-ConfigOrEnvironmentValue $store "ClientId" "MS_STORE_CLIENT_ID") "MicrosoftStore.ClientId / MS_STORE_CLIENT_ID"
  $clientSecret = Get-RequiredValue ([Environment]::GetEnvironmentVariable("MS_STORE_CLIENT_SECRET")) "MS_STORE_CLIENT_SECRET"
  $sellerId = Get-RequiredValue (Get-ConfigOrEnvironmentValue $store "SellerId" "MS_STORE_SELLER_ID") "MicrosoftStore.SellerId / MS_STORE_SELLER_ID"

  Invoke-Checked "Building Windows release" { flutter build windows --release "--dart-define=BASE_URL=$baseUrl" }
  $windowsReleaseDirectory = Join-Path $projectRoot "build/windows/x64/runner/Release"
  if (-not (Test-Path -LiteralPath $windowsReleaseDirectory)) { throw "Windows release directory was not created: $windowsReleaseDirectory" }
  $dlls = @(Get-ChildItem -Path "dependencies/*.dll" -File)
  if ($dlls.Count -eq 0) { throw "No runtime DLLs found in dependencies." }
  Copy-Item -Path "dependencies/*.dll" -Destination $windowsReleaseDirectory -Force

  Invoke-Checked "Configuring Microsoft Store CLI" {
    msstore reconfigure --tenantId $tenantId --clientId $clientId --clientSecret $clientSecret --sellerId $sellerId
  }
  $msixDirectory = Join-Path $artifactDirectory "microsoft-store"
  New-Item -ItemType Directory -Path $msixDirectory -Force | Out-Null
  Invoke-Checked "Creating Microsoft Store package" {
    msstore package --input-directory $windowsReleaseDirectory --output-directory $msixDirectory
  }
  $msixFiles = @(Get-ChildItem -Path $msixDirectory -Filter "*.msix" -File)
  if ($msixFiles.Count -eq 0) { throw "msstore package did not create an .msix file in $msixDirectory" }
  $msixFiles | ForEach-Object { $builtArtifacts.Add($_.FullName) }
  Invoke-Checked "Publishing package to Microsoft Store" { msstore publish -v $msixDirectory }
}

if (-not $SkipGoogleDrive) {
  Assert-Command "rclone" "Install rclone, then run: rclone config (create a Google Drive remote)."
  $drive = $config.GoogleDrive
  $remote = Get-RequiredValue $drive.Remote "GoogleDrive.Remote"
  $folder = Get-RequiredValue $drive.Folder "GoogleDrive.Folder"
  if ($builtArtifacts.Count -eq 0) { throw "There are no artifacts to upload. Do not skip both store builds when Drive upload is enabled." }
  $destination = "{0}:{1}/{2}+{3}" -f $remote.TrimEnd(':'), $folder.Trim('/'), $releaseVersion, $buildNumber
  Invoke-Checked "Uploading release artifacts to Google Drive ($destination)" { rclone copy $artifactDirectory $destination --create-empty-src-dirs }
}

Write-Host "" 
Write-Host "Release $releaseVersion+$buildNumber completed." -ForegroundColor Green
if ($KeepArtifacts) {
  Write-Host "Artifacts retained: $artifactDirectory" -ForegroundColor Green
} else {
  Remove-Item -LiteralPath $artifactDirectory -Recurse -Force
  Write-Host "Temporary artifacts removed. Use -KeepArtifacts to retain them locally." -ForegroundColor DarkGray
}
