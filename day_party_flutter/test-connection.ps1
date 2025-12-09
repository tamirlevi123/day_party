# Test script to verify emulator connectivity
Write-Host "Testing Android Emulator Connection..." -ForegroundColor Cyan
Write-Host ""

# Check if emulator is connected
Write-Host "1. Checking connected devices..." -ForegroundColor Yellow
$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    & $adbPath devices
    Write-Host ""
} else {
    Write-Host "❌ ADB not found at: $adbPath" -ForegroundColor Red
    exit 1
}

# Check port forwarding
Write-Host "2. Checking port forwarding..." -ForegroundColor Yellow
$forwarding = & $adbPath reverse --list
if ($forwarding -match "tcp:3000") {
    Write-Host "✅ Port forwarding is active: $forwarding" -ForegroundColor Green
} else {
    Write-Host "⚠️ Port forwarding not found. Setting it up..." -ForegroundColor Yellow
    & $adbPath reverse tcp:3000 tcp:3000
    Write-Host "✅ Port forwarding set up" -ForegroundColor Green
}
Write-Host ""

# Check backend
Write-Host "3. Checking backend server..." -ForegroundColor Yellow
$backend = netstat -ano | findstr ":3000"
if ($backend) {
    Write-Host "✅ Backend is running on port 3000" -ForegroundColor Green
    Write-Host "   $backend" -ForegroundColor Gray
} else {
    Write-Host "❌ Backend is NOT running on port 3000" -ForegroundColor Red
    Write-Host "   Start it with: cd backend ; npm run dev" -ForegroundColor Yellow
}
Write-Host ""

# Test backend health
Write-Host "4. Testing backend health endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Backend is responding: $($response.Content)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Backend health check failed: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Make sure backend is running: cd backend ; npm run dev" -ForegroundColor White
Write-Host "2. Port forwarding is active (checked above)" -ForegroundColor White
Write-Host "3. FULLY RESTART the Flutter app (stop and restart, not hot reload)" -ForegroundColor Yellow
Write-Host "4. Tap 'Retry' button in the app if error persists" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

