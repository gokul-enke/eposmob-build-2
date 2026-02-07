param(
  [string]$BaseUrl = "https://eeezeeerp.cloudposai.com",
  [string]$OutputName = "cloudpos"
)

$ErrorActionPreference = "Stop"

# Step 1: Clean previous build first
Write-Host "==> [1/6] Cleaning previous build..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }

# Step 2: Install dependencies after clean
Write-Host "==> [2/6] Installing dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

# Step 3: Build Windows release
Write-Host "==> [3/6] Building Windows release (this may take a few minutes)..." -ForegroundColor Cyan
flutter build windows --release --dart-define=BASE_URL=$BaseUrl
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

$releaseX64 = "build/windows/x64/runner/Release"
$msixPath = "build/windows/runner/Release"

# Step 4: Copy runtime DLLs
Write-Host "==> [4/6] Copying runtime DLLs..." -ForegroundColor Cyan
Copy-Item -Path "dependencies/*.dll" -Destination $releaseX64 -Force

# Step 5: Prepare MSIX build path (copy x64 output to expected msix location)
Write-Host "==> [5/6] Preparing MSIX build path..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $msixPath | Out-Null
Get-ChildItem -Path $releaseX64 | ForEach-Object {
  Copy-Item -Path $_.FullName -Destination $msixPath -Recurse -Force
}

# Step 6: Create MSIX package (using dart run instead of deprecated flutter pub run)
Write-Host "==> [6/6] Creating MSIX package (verbose)..." -ForegroundColor Cyan
dart run msix:create --build-windows false -v
if ($LASTEXITCODE -ne 0) { throw "msix:create failed" }

# Rename output
Write-Host "==> Renaming MSIX output..." -ForegroundColor Cyan
$msixFile = Get-ChildItem -Path $msixPath -Filter "*.msix" | Select-Object -First 1
if (-not $msixFile) {
  # Also check the x64 path in case msix wrote there
  $msixFile = Get-ChildItem -Path $releaseX64 -Filter "*.msix" | Select-Object -First 1
}
if (-not $msixFile) {
  throw "MSIX package not found in $msixPath or $releaseX64"
}
Rename-Item -Path $msixFile.FullName -NewName ("$OutputName.msix") -Force

Write-Host ""
Write-Host "==> Done! MSIX package created successfully." -ForegroundColor Green
Write-Host "MSIX: $($msixFile.DirectoryName)\$OutputName.msix"
