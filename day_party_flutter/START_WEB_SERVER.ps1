# Start Flutter Web Server on fixed port 8080
# This will NOT launch Chrome - you manually open the URL

Write-Host "Starting Flutter Web Server on port 8080..." -ForegroundColor Green
Write-Host ""
Write-Host "After it starts, manually open: http://localhost:8080" -ForegroundColor Yellow
Write-Host ""

Set-Location $PSScriptRoot
flutter run -d web-server --web-port=8080 --web-hostname=localhost

