# Emulator Login Fix Guide

## Problem
When trying to log in via Google OAuth on the Android emulator, the browser shows `ERR_CONNECTION_REFUSED` when accessing `localhost:3000`. This happens because `localhost` in the emulator refers to the emulator itself, not your host machine.

## Solution: Port Forwarding (ADB Reverse Tunneling)

**⚠️ CRITICAL**: You must set up ADB reverse port forwarding to tunnel `localhost:3000` from the emulator to your host machine's `localhost:3000`.

**Required Port Forwarding**: `adb reverse tcp:3000 tcp:3000`

This creates a TCP tunnel that forwards connections from the emulator's `localhost:3000` to your host machine's `localhost:3000` where the backend server is running.

**See `EMULATOR_SETUP.md` in the project root for complete setup instructions.**

## Verification

### 1. Check Port Forwarding is Active
Run this command in PowerShell:
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

You should see the backend listening on port 3000.

### 3. Test from Emulator Browser
1. Open a browser in the emulator
2. Navigate to: `http://localhost:3000/health`
3. You should see: `{"status":"OK","timestamp":"..."}`

## Login Flow

### Normal Flow (with port forwarding):
1. Tap "התחבר עם Google" (Sign in with Google)
2. Browser opens and redirects to Google OAuth
3. After authentication, Google redirects to `http://localhost:3000/api/auth/google/callback`
4. Backend shows a page with the authorization code
5. The page automatically tries to open the app via deep link (`dayparty://auth/callback?code=...`)
6. App receives the code and completes authentication

### Manual Flow (if deep link doesn't work):
1. Follow steps 1-4 above
2. Copy the authorization code from the page
3. In the app, tap "הזן קוד ידנית" (Enter code manually)
4. Paste the code and tap "התחבר" (Sign in)

## If Port Forwarding Doesn't Work

### Option 1: Re-run Port Forwarding Script (Recommended)
```cmd
cd day_party_flutter
setup-port-forwarding.cmd
```

**Alternative PowerShell version** (may require execution policy bypass):
```powershell
cd day_party_flutter
powershell -ExecutionPolicy Bypass -File .\setup-port-forwarding.ps1
```

### Option 2: Manual ADB Command
```powershell
$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adbPath reverse tcp:3000 tcp:3000
```

### Option 3: Check ADB Path
If ADB is not found, locate it:
- `%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe`
- `%ProgramFiles%\Android\Android Studio\platform-tools\adb.exe`
- `C:\Android\platform-tools\adb.exe`

Then run:
```powershell
& "PATH_TO_ADB\adb.exe" reverse tcp:3000 tcp:3000
```

## Troubleshooting

### Issue: Port forwarding resets after emulator restart
**Solution:** Port forwarding needs to be set up each time you restart the emulator. You can:
1. Re-run the setup script
2. Or add it to your startup script

### Issue: Backend not accessible
**Solution:** Ensure backend is running:
```powershell
cd backend
npm run dev
```

### Issue: Deep link doesn't open app
**Solution:** Use the manual code entry option:
1. Copy code from browser
2. Use "הזן קוד ידנית" button in app
3. Paste code and submit

### Issue: Code expires
**Solution:** OAuth codes expire quickly. If the code doesn't work:
1. Go back to login screen
2. Try signing in again
3. Copy the new code immediately

## Testing Checklist

- [ ] Backend is running on port 3000
- [ ] Port forwarding is active (`adb reverse --list` shows port 3000)
- [ ] Can access `http://localhost:3000/health` from emulator browser
- [ ] Google OAuth redirects to callback page
- [ ] Callback page shows authorization code
- [ ] Deep link opens app (or manual code entry works)
- [ ] Login completes successfully

## Notes

- Port forwarding only works while the emulator is running
- You need to set up port forwarding each time you restart the emulator
- The backend must be running on your host machine
- For physical devices, use your computer's network IP address (not localhost)

