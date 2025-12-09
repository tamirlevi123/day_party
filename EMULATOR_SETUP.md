# Android Emulator Setup Guide

## ⚠️ CRITICAL: Port Forwarding Required for OAuth

**IMPORTANT**: When running the Day Party app on an Android emulator, you **MUST** set up ADB reverse port forwarding for OAuth authentication to work.

## Why Port Forwarding is Needed

The Day Party app uses two different connection methods in the emulator:

1. **App API Calls**: The Flutter app connects to `http://10.0.2.2:3000/api` (the special Android emulator IP that maps to host's localhost)
2. **OAuth Callbacks**: Google OAuth redirects to `http://localhost:3000/api/auth/google/callback` (which in the emulator refers to the emulator itself, not your host machine)

**The Problem**: When Google redirects to `localhost:3000` in the emulator's browser, it tries to connect to the emulator itself, not your development machine where the backend is running.

**The Solution**: ADB reverse port forwarding tunnels `localhost:3000` from the emulator to `localhost:3000` on your host machine.

## Required Port Forwarding Configuration

### Port Forwarding Details

- **Source**: `localhost:3000` (in Android emulator)
- **Destination**: `localhost:3000` (on your Windows host machine)
- **Protocol**: TCP
- **ADB Command**: `adb reverse tcp:3000 tcp:3000`

This creates a tunnel that forwards any connection to `localhost:3000` in the emulator to `localhost:3000` on your host machine where the backend server is running.

## Setup Instructions

### Option 1: Use the Setup Script (Recommended)

```powershell
cd day_party_flutter
.\setup-port-forwarding.ps1
```

This script will:
- Locate ADB automatically
- Set up the port forwarding
- Verify it's active
- Show you the status

### Option 2: Manual ADB Command

If ADB is in your PATH:
```powershell
adb reverse tcp:3000 tcp:3000
```

If ADB is not in PATH, use the full path:
```powershell
$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adbPath reverse tcp:3000 tcp:3000
```

### Option 3: Alternative ADB Locations

If ADB is not found at the default location, check these paths:
- `%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe` (default)
- `%ProgramFiles%\Android\Android Studio\platform-tools\adb.exe`
- `C:\Android\platform-tools\adb.exe`

Then run:
```powershell
& "PATH_TO_ADB\adb.exe" reverse tcp:3000 tcp:3000
```

## Verification

### 1. Check Port Forwarding is Active

```powershell
$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adbPath reverse --list
```

You should see:
```
host-16 tcp:3000 tcp:3000
```

### 2. Verify Backend is Running

```powershell
netstat -ano | findstr :3000
```

You should see the backend listening on port 3000:
```
TCP    0.0.0.0:3000           0.0.0.0:0              LISTENING       <PID>
```

### 3. Test from Emulator Browser

1. Open a browser in the Android emulator
2. Navigate to: `http://localhost:3000/health`
3. You should see: `{"status":"OK","timestamp":"..."}`

If this works, port forwarding is configured correctly!

## Important Notes

### ⚠️ Port Forwarding Resets on Emulator Restart

**CRITICAL**: Port forwarding is **NOT persistent**. Every time you restart the Android emulator, you must set up port forwarding again.

**Solution**: Re-run the setup script or ADB command after each emulator restart:
```powershell
cd day_party_flutter
.\setup-port-forwarding.ps1
```

### Backend Must Be Running

The backend server must be running on your host machine for port forwarding to work:
```powershell
cd backend
npm run dev
```

The backend should be listening on `0.0.0.0:3000` (all interfaces) as configured in `backend/src/server.ts`.

### When Port Forwarding is Needed

Port forwarding is required for:
- ✅ Google OAuth login flow (callbacks use `localhost:3000`)
- ✅ Testing OAuth redirects in emulator browser
- ✅ Any browser-based authentication flows

Port forwarding is **NOT** needed for:
- ❌ Regular app API calls (app uses `10.0.2.2:3000` which works without port forwarding)
- ❌ Physical device testing (physical devices use your network IP address)

## Troubleshooting

### Issue: Port forwarding doesn't work

**Check ADB connection:**
```powershell
adb devices
```
Should show your emulator listed.

**Check if port forwarding is active:**
```powershell
adb reverse --list
```
Should show `tcp:3000 tcp:3000`.

**Solution**: Re-run the setup script or manually set up port forwarding again.

### Issue: Backend not accessible from emulator

**Check backend is running:**
```powershell
netstat -ano | findstr :3000
```

**Check backend is listening on all interfaces:**
In `backend/src/server.ts`, verify:
```typescript
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Day Party API server running on port ${PORT}`);
});
```

**Solution**: Start the backend if not running, or fix the listen configuration.

### Issue: Port 3000 already in use

**Find the process using port 3000:**
```powershell
netstat -ano | findstr :3000
```

**Kill the process:**
```powershell
taskkill /PID <PID> /F
```

Or use this one-liner:
```powershell
Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess | ForEach-Object { taskkill /PID $_ /F }
```

### Issue: OAuth callback shows ERR_CONNECTION_REFUSED

This means port forwarding is not active or backend is not running.

**Solution**:
1. Verify backend is running: `netstat -ano | findstr :3000`
2. Set up port forwarding: `.\setup-port-forwarding.ps1`
3. Test from emulator browser: `http://localhost:3000/health`
4. Try OAuth login again

## Quick Reference

### Setup Port Forwarding
```powershell
cd day_party_flutter
.\setup-port-forwarding.ps1
```

### Verify Port Forwarding
```powershell
adb reverse --list
```

### Check Backend Status
```powershell
netstat -ano | findstr :3000
```

### Test from Emulator
Open browser in emulator → `http://localhost:3000/health`

## Related Documentation

- `day_party_flutter/EMULATOR_LOGIN_FIX.md` - Detailed OAuth login troubleshooting
- `day_party_flutter/TROUBLESHOOTING.md` - General connection troubleshooting
- `QUICK_FIX_SUMMARY.md` - Quick reference for emulator login issues
- `day_party_flutter/setup-port-forwarding.ps1` - Port forwarding setup script

## Summary

**For Android Emulator Development:**

1. ✅ Start backend: `cd backend ; npm run dev`
2. ✅ Start Android emulator
3. ✅ **Set up port forwarding**: `cd day_party_flutter ; .\setup-port-forwarding.ps1`
4. ✅ Verify: Test `http://localhost:3000/health` in emulator browser
5. ✅ Run Flutter app: `flutter run`

**Remember**: Port forwarding must be set up **every time you restart the emulator**!

