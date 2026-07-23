param(
  [string]$BaseUrl = "https://eeezeeerp.cloudposai.com",
  [string]$InnoSetupPath,
  [switch]$SkipClean
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Assert-ExitCode([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter was not found on PATH. Install Flutter and reopen PowerShell."
}

$iscc = $null
if ($InnoSetupPath) {
  if (-not (Test-Path -LiteralPath $InnoSetupPath)) {
    throw "The specified Inno Setup compiler was not found: $InnoSetupPath"
  }
  $iscc = (Resolve-Path -LiteralPath $InnoSetupPath).Path
} else {
  $isccCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
  )
  $iscc = $isccCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

  if (-not $iscc) {
    $isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($isccCommand) { $iscc = $isccCommand.Source }
  }
}
if (-not $iscc) {
  throw "Inno Setup is installed but ISCC.exe was not found. Locate it with: where.exe /r C:\\ ISCC.exe, then run with -InnoSetupPath <full path>"
}
Write-Host "Using Inno Setup: $iscc"

$versionLine = Get-Content pubspec.yaml |
  Where-Object { $_ -match '^version:\s+\S+' } |
  Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s+(\S+)') {
  throw "Could not read a valid version from pubspec.yaml"
}
$version = $Matches[1]
if ($version -notmatch '^\d+\.\d+\.\d+(\+\d+)?$') {
  throw "Unsupported pubspec version: $version"
}
$releaseVersion = $version.Replace('+', '.')
$expected = "cloudpos-$releaseVersion.exe"

Write-Host "Building CLOUDPOS $releaseVersion for $BaseUrl" -ForegroundColor Cyan

if (-not $SkipClean) {
  flutter clean
  Assert-ExitCode "flutter clean"
}

flutter pub get
Assert-ExitCode "flutter pub get"

flutter build windows --release "--dart-define=BASE_URL=$BaseUrl"
Assert-ExitCode "flutter build windows"

$releaseDir = "build\windows\x64\runner\Release"
$dlls = @(Get-ChildItem -Path "dependencies\*.dll" -File)
if ($dlls.Count -eq 0) {
  throw "No dependency DLLs found in dependencies"
}
Copy-Item -Path "dependencies\*.dll" -Destination $releaseDir -Force

$outputDir = "Output"
if (Test-Path $outputDir) {
  Remove-Item $outputDir -Recurse -Force
}

& $iscc "/DMyAppVersion=$releaseVersion" ".\inno_setup.iss"
Assert-ExitCode "Inno Setup"

$installers = @(Get-ChildItem -Path $outputDir -Filter "*.exe" -File)
$expectedPath = Join-Path $outputDir $expected
if ($installers.Count -ne 1 -or -not (Test-Path $expectedPath)) {
  $found = $installers.Name -join ', '
  throw "Expected exactly one installer named $expectedPath; found: $found"
}

Write-Host "Created: $((Resolve-Path $expectedPath).Path)" -ForegroundColor Green
