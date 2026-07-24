# MovieHub Private Build Script
# This script builds the full version with card images for personal use

Write-Host "Building MovieHub Private Release (with card images)..." -ForegroundColor Green

# Step 1: Build the application
Write-Host "`nStep 1/2: Building Flutter Windows Release..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Step 2: Verify cards are included
Write-Host "`nStep 2/2: Verifying card images..." -ForegroundColor Cyan
$cardsPath = "build\windows\x64\runner\Release\data\flutter_assets\assets\cards\images"

if (Test-Path $cardsPath) {
    $cardCount = (Get-ChildItem -Path $cardsPath -Include *.png,*.jpg,*.jpeg,*.webp -Recurse).Count
    Write-Host "Found $cardCount card images in build" -ForegroundColor Green
} else {
    Write-Host "Warning: No cards found in build output" -ForegroundColor Yellow
}

# Step 3: Build complete
Write-Host "`nBuild complete!" -ForegroundColor Green
Write-Host "Output: build\windows\x64\runner\Release\" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Open installer\MovieHub.iss with Inno Setup" -ForegroundColor White
Write-Host "  2. Compile to create private installer with card images" -ForegroundColor White
Write-Host "  3. Keep for personal use only" -ForegroundColor White
