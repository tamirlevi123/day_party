# Android Gradle Tasks for Cursor

You can run these Gradle commands from Cursor's terminal to build, test, and deploy your Android app.

## ⚠️ IMPORTANT: Windows Command Line Syntax

**FOR AI AGENTS AND DEVELOPERS**: This project runs on **Windows PowerShell**. 

- **DO NOT use `&&`** to chain commands (this is Unix/Linux syntax)
- **USE `;` (semicolon)** instead to chain commands in PowerShell
- Example: `cd dir1 ; cd dir2` ✅ (correct for Windows)
- Example: `cd dir1 && cd dir2` ❌ (will fail on Windows)

See `03-Decision-Log.md` for full details on Windows command line constraints.

## Prerequisites

Make sure you have:
- Java JDK installed (Android Studio comes with one)
- ADB available in PATH (Android SDK `platform-tools`)
- An emulator running or a physical device connected

## Common Tasks

### Build Commands

```powershell
# Sync Gradle dependencies
cd E:\day_party\frontend
.\gradlew.bat build --refresh-dependencies

# Clean build
.\gradlew.bat clean

# Build debug APK
.\gradlew.bat assembleDebug

# Build release APK
.\gradlew.bat assembleRelease
```

### Install & Run

```powershell
# Install debug APK on connected device
.\gradlew.bat installDebug

# Run the app on connected device
.\gradlew.bat installDebug -x test

# Build and install in one command
.\gradlew.bat installDebug --refresh-dependencies
```

### Check Devices

```powershell
# List connected devices
adb devices

# Check if emulator is running
adb -s emulator-5554 shell getprop ro.product.model

# Port Forwarding for OAuth (REQUIRED for emulator testing)
# ADB Reverse Port Forwarding: Forward emulator's localhost:3000 to host machine's localhost:3000
# This creates a TCP tunnel that allows Google OAuth redirects to work in emulator
# See EMULATOR_SETUP.md in project root for complete documentation

# Option 1: Use the helper script (recommended)
cd day_party_flutter
.\setup-port-forwarding.ps1

# Option 2: Run ADB directly (if ADB is in PATH)
adb reverse tcp:3000 tcp:3000

# Option 3: Use full path to ADB (if ADB is not in PATH)
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000

# Verify port forwarding
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse --list
```

### Logs

```powershell
# View app logs
adb logcat -c
adb logcat | findstr "DayParty"

# Clear logs and view fresh output
# IMPORTANT: On Windows PowerShell, use ; (semicolon) NOT && (ampersand-ampersand)
adb logcat -c ; adb logcat

# Filter by specific tags (useful for debugging)
adb logcat | findstr "DayParty OkHttp Retrofit"
```

### Testing

```powershell
# Run unit tests
.\gradlew.bat test

# Run instrumented tests
.\gradlew.bat connectedAndroidTest

# Run specific test class
.\gradlew.bat test --tests "com.dayparty.app.TestClass"
```

### Development Workflow

```powershell
# 1. Make sure backend is running locally
cd E:\day_party\backend
npm run dev

# 2. Make sure emulator is running
# (Launch from Android Studio or via command line)

# 3. Install app
cd E:\day_party\frontend
.\gradlew.bat installDebug

# 4. View logs in another terminal
adb logcat | findstr "DayParty"
```

### Debugging Tips

```powershell
# Uninstall app from device
adb uninstall com.dayparty.app

# Clear app data (useful for testing clean state)
adb shell pm clear com.dayparty.app

# Check app's network traffic (see network security config)
adb logcat | findstr "CLEARTEXT\|SSL\|TLS"

# View device file system
adb shell ls /data/data/com.dayparty.app/

# Pull app database (if using SQLite)
adb shell "run-as com.dayparty.app cat databases/app.db" > app.db
```

## Quick Reference for This Project

### Current Setup
- **Backend**: `E:\day_party\backend` - Node.js on port 3000
- **Frontend**: `E:\day_party\frontend` - Android app
- **Emulator alias**: `10.0.2.2:3000` (maps to `localhost:3000`)

### Typical Development Cycle

1. **Edit Kotlin files** in Cursor
2. **Rebuild**: `.\gradlew.bat installDebug`
3. **Test**: App auto-launches on emulator
4. **Debug**: `adb logcat | findstr "DayParty"`

### Troubleshooting

```powershell
# If Gradle daemon is stuck
.\gradlew.bat --stop

# If build cache is corrupted
.\gradlew.bat cleanBuildCache

# If dependencies won't resolve
.\gradlew.bat clean
rm -r .gradle
.\gradlew.bat build --refresh-dependencies
```

## Integration with Android Studio

You can still use Android Studio for:
- **Visual debugging** with breakpoints
- **Layout editor** for Compose preview
- **Profiler** for performance analysis
- **Device manager** for emulator setup

But for quick iterations and log viewing, these Gradle commands work great from Cursor!

