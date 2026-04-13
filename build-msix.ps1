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

# Step 4: Copy runtime DLLs to x64 build output
Write-Host "==> [4/6] Copying runtime DLLs..." -ForegroundColor Cyan
Copy-Item -Path "dependencies/*.dll" -Destination $releaseX64 -Force

# Step 5: Prepare MSIX build path (copy x64 output to expected msix location)
Write-Host "==> [5/6] Preparing MSIX build path..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $msixPath | Out-Null
Get-ChildItem -Path $releaseX64 | ForEach-Object {
  Copy-Item -Path $_.FullName -Destination $msixPath -Recurse -Force
}

# Also ensure VC++ DLLs are explicitly in the msix source directory
Copy-Item -Path "dependencies/*.dll" -Destination $msixPath -Force

# Step 6: Create MSIX package (using dart run instead of deprecated flutter pub run)
Write-Host "==> [6/7] Creating MSIX package (verbose)..." -ForegroundColor Cyan
dart run msix:create --build-windows false -v
if ($LASTEXITCODE -ne 0) { throw "msix:create failed" }

# Step 7: Sign the MSIX with certificate
Write-Host "==> [7/7] Signing MSIX package..." -ForegroundColor Cyan
$certPath = "certificate.pfx"
$certPassword = "1234"
if (Test-Path $certPath) {
  $signtool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter "signtool.exe" |
    Where-Object { $_.FullName -like "*\x64\*" } | Select-Object -Last 1
  if ($signtool) {
    $msixToSign = Get-ChildItem -Path $msixPath -Filter "*.msix" | Select-Object -First 1
    if (-not $msixToSign) {
      $msixToSign = Get-ChildItem -Path $releaseX64 -Filter "*.msix" | Select-Object -First 1
    }
    & $signtool.FullName sign /fd SHA256 /a /f $certPath /p $certPassword $msixToSign.FullName
    if ($LASTEXITCODE -ne 0) { throw "MSIX signing failed" }
    Write-Host "MSIX signed successfully." -ForegroundColor Green
  } else {
    Write-Host "WARNING: signtool.exe not found. MSIX is unsigned." -ForegroundColor Yellow
  }
} else {
  Write-Host "WARNING: certificate.pfx not found. MSIX is unsigned." -ForegroundColor Yellow
}

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
