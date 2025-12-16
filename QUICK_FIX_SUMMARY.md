# Quick Fix Summary: Emulator Login Issue

## ✅ What Was Fixed

1. **Port Forwarding Set Up**: ADB port forwarding is now active, allowing the emulator browser to access `localhost:3000` on your host machine.

2. **OAuth Callback Improved**: The callback page now tries to open the deep link automatically with better timing for emulator compatibility.

## 🔍 The Problem

When logging in via Google OAuth on the Android emulator:
- Google redirects to `http://localhost:3000/api/auth/google/callback`
- The emulator's browser tried to access `localhost:3000`
- But `localhost` in the emulator refers to the emulator itself, not your host machine
- Result: `ERR_CONNECTION_REFUSED`

## ✅ The Solution

**ADB Reverse Port Forwarding** (IP tunneling) maps `localhost:3000` in the emulator to `localhost:3000` on your host machine, so the browser can reach your backend server.

**Required Command**: `adb reverse tcp:3000 tcp:3000`

This creates a TCP tunnel that forwards the emulator's `localhost:3000` to your host machine's `localhost:3000`.

**See `EMULATOR_SETUP.md` in the project root for complete setup instructions.**

## 🧪 How to Test

1. **Verify Backend is Running**:
   ```powershell
   netstat -ano | findstr :3000
   ```
   Should show the backend listening on port 3000.

2. **Verify Port Forwarding**:
   ```powershell
   $adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
   & $adbPath reverse --list
   ```
   Should show: `host-16 tcp:3000 tcp:3000`

3. **Test in Emulator Browser**:
   - Open browser in emulator
   - Navigate to: `http://localhost:3000/health`
   - Should see: `{"status":"OK","timestamp":"..."}`

4. **Test Login Flow**:
   - Open the Day Party app in emulator
   - Tap "התחבר עם Google" (Sign in with Google)
   - Complete Google authentication
   - Should see callback page with authorization code
   - App should open automatically, or use manual code entry

## 📝 Important Notes

- **Port forwarding resets** when you restart the emulator - you'll need to run the setup again
- To re-setup port forwarding (recommended: use .cmd version):
  ```cmd
  cd day_party_flutter
  setup-port-forwarding.cmd
  ```
  Or PowerShell version:
  ```powershell
  cd day_party_flutter
  powershell -ExecutionPolicy Bypass -File .\setup-port-forwarding.ps1
  ```
  Or manually:
  ```powershell
  $adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
  & $adbPath reverse tcp:3000 tcp:3000
  ```

- **Backend must be running** on your host machine for this to work
- **Manual code entry** is available as a fallback if deep links don't work

## 🆘 If It Still Doesn't Work

1. Check backend is running: `cd backend && npm run dev`
2. Verify port forwarding: `adb reverse --list`
3. Test backend from emulator browser: `http://localhost:3000/health`
4. Use manual code entry option in the app
5. Check `day_party_flutter/EMULATOR_LOGIN_FIX.md` for detailed troubleshooting

## 📚 Related Files

- `day_party_flutter/EMULATOR_LOGIN_FIX.md` - Detailed troubleshooting guide
- `day_party_flutter/setup-port-forwarding.cmd` - Port forwarding script (recommended, bypasses PowerShell execution policy)
- `day_party_flutter/setup-port-forwarding.ps1` - PowerShell version of port forwarding script
- `backend/src/controllers/auth.controller.ts` - OAuth callback handler

