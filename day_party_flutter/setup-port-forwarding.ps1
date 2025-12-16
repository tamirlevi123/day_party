# Port Forwarding Script for Android Emulator OAuth Testing
# 
# This script sets up ADB reverse port forwarding (IP tunneling) to forward
# localhost:3000 from the Android emulator to localhost:3000 on your host machine.
#
# Why this is needed:
# - The Flutter app uses 10.0.2.2:3000 for API calls (works without port forwarding)
# - Google OAuth redirects to localhost:3000 (needs port forwarding)
# - localhost in emulator refers to emulator itself, not your host machine
#
# Required: adb reverse tcp:3000 tcp:3000
# This creates a TCP tunnel: emulator localhost:3000 -> host localhost:3000
#
# IMPORTANT: Port forwarding resets when you restart the emulator!
# You must run this script again after each emulator restart.
#
# See EMULATOR_SETUP.md in the project root for complete documentation.
#
# Usage (recommended order):
#   1. .cmd version (bypasses PowerShell execution policy): .\setup-port-forwarding.cmd
#   2. PowerShell with bypass: powershell -ExecutionPolicy Bypass -File .\setup-port-forwarding.ps1
#   3. Direct PowerShell (may fail if execution policy is restricted): .\setup-port-forwarding.ps1

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

