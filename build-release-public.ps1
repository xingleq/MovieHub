# MovieHub Public Release Build Script
# This script builds a version without copyrighted card images for GitHub Release

Write-Host "Building MovieHub Public Release (without card images)..." -ForegroundColor Green

# Step 1: Build the application
Write-Host "`nStep 1/3: Building Flutter Windows Release..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Step 2: Remove card images from build output
Write-Host "`nStep 2/3: Removing card images from build output..." -ForegroundColor Cyan
$cardsPath = "build\windows\x64\runner\Release\data\flutter_assets\assets\cards\images"

if (Test-Path $cardsPath) {
    # Keep the directory structure but remove image files
    Get-ChildItem -Path $cardsPath -Include *.png,*.jpg,*.jpeg,*.webp -Recurse | Remove-Item -Force
    Write-Host "Card images removed from: $cardsPath" -ForegroundColor Yellow
} else {
    Write-Host "Cards path not found (already clean): $cardsPath" -ForegroundColor Yellow
}

# Step 3: Build installer
Write-Host "`nStep 3/3: Build complete!" -ForegroundColor Green
Write-Host "Output: build\windows\x64\runner\Release\" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Open installer\MovieHub.iss with Inno Setup" -ForegroundColor White
Write-Host "  2. Compile to create installer without card images" -ForegroundColor White
Write-Host "  3. Upload to GitHub Release" -ForegroundColor White
