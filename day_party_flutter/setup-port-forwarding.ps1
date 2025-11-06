# Port Forwarding Script for Android Emulator OAuth Testing
# This forwards localhost:3000 from emulator to host machine

$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

if (Test-Path $adbPath) {
    Write-Host "Setting up port forwarding: localhost:3000 (emulator) -> localhost:3000 (host)" -ForegroundColor Green
    & $adbPath reverse tcp:3000 tcp:3000
    
    Write-Host "`nVerifying port forwarding:" -ForegroundColor Yellow
    & $adbPath reverse --list
    
    Write-Host "`n✅ Port forwarding is active!" -ForegroundColor Green
    Write-Host "You can now test OAuth in the emulator." -ForegroundColor Cyan
} else {
    Write-Host "❌ ADB not found at: $adbPath" -ForegroundColor Red
    Write-Host "Please ensure Android SDK is installed." -ForegroundColor Yellow
}

