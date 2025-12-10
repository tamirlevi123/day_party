# Web Debug Guide

## Fixed Issues ✅

### 1. Fixed Port (Always 8080)
The port is now fixed to 8080 using `--web-port=8080`.

### 2. Browser Console Logging
Logs now appear in **both**:
- ✅ Flutter debug console (when Flutter launches Chrome)
- ✅ Browser DevTools console (when you manually open the URL)

## ⚠️ Important: VS Code Extension Limitation

**The Flutter/Dart extension in VS Code/Cursor may still launch Chrome automatically**, even with `web-server` device. This is a known limitation of the extension.

## Solution: Use Terminal Command (Recommended)

### Option 1: Use the Script (Easiest)

**Windows:**
```powershell
cd day_party_flutter
.\START_WEB_SERVER.ps1
```

**Or double-click:** `START_WEB_SERVER.bat`

### Option 2: Manual Command

```powershell
cd day_party_flutter
flutter run -d web-server --web-port=8080 --web-hostname=localhost
```

### Then:
1. Wait for: `Serving at http://localhost:8080`
2. **Manually open** `http://localhost:8080` in your existing browser
3. You'll stay logged into Google ✅
4. **Hot reload still works** ✅

### View Logs
1. Press **F12** in your browser
2. Go to **Console** tab
3. You'll see all logs with 🎥 emoji for video-related logs

## Alternative: Use Debug Config (May Launch Chrome)

If you want to try the debug config anyway:
1. Select **"day_party_flutter (Web Server - No Chrome)"** from debug dropdown
2. Press **F5**
3. If Chrome launches, close it and manually open `http://localhost:8080`

## Port Configuration

The port is **fixed to 8080** via:
- Launch config: `--web-port=8080`
- Always use: `http://localhost:8080`

If port 8080 is busy, Flutter will show an error. To use a different port:
1. Edit `.vscode/launch.json`
2. Change `--web-port=8080` to your preferred port
3. Update the URL you open in browser

## Benefits

✅ **Consistent port** - Always 8080  
✅ **Browser console logs** - See logs in manually opened browsers  
✅ **Google session** - Stay logged in  
✅ **Hot reload** - Changes apply automatically  
✅ **Debug support** - Breakpoints work in both scenarios  

## Troubleshooting

### Port Already in Use
```powershell
# Check what's using port 8080
netstat -ano | findstr :8080

# Kill the process if needed (replace <PID> with actual process ID)
taskkill /PID <PID> /F
```

### Logs Not Appearing in Browser Console
1. Make sure you're opening the browser **after** starting the debug session
2. Check browser console (F12 → Console tab)
3. Verify the app is running in debug mode (not release)

### Hot Reload Not Working
- Hot reload works when you manually open the browser
- Make sure the debug session is still running in Cursor
- Changes will apply automatically when you save files

