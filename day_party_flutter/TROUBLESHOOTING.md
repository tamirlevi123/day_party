# Flutter App Troubleshooting Guide

## Connection Timeout Issues

If you're experiencing connection timeout errors when running the Flutter app on a physical device, follow these steps:

### 1. Verify Backend Server is Running

On your development machine, check if the backend is running:

```powershell
# Check if Node.js backend is running on port 3000
netstat -ano | findstr :3000
```

Or test the health endpoint directly:
```powershell
# From your development machine
curl http://localhost:3000/health
```

### 2. Verify IP Address

The app is configured to connect to `http://192.168.0.101:3000/api` for physical devices.

**To find your computer's IP address:**

**Windows:**
```powershell
ipconfig
# Look for "IPv4 Address" under your active network adapter (usually Wi-Fi or Ethernet)
```

**Update the IP in the code:**
- Edit `day_party_flutter/lib/core/api_client.dart`
- Change `_localDeviceBaseUrl` to match your current IP address
- Example: `static const String _localDeviceBaseUrl = 'http://YOUR_IP_HERE:3000/api';`

### 3. Verify Same Network

- **Both devices must be on the same Wi-Fi network**
- The physical device and your development machine must be connected to the same router/network
- Mobile data will NOT work - you need Wi-Fi

### 4. Check Firewall

Windows Firewall may be blocking incoming connections on port 3000.

**To allow Node.js through Windows Firewall:**

1. Open Windows Defender Firewall
2. Click "Allow an app or feature through Windows Defender Firewall"
3. Find "Node.js" and ensure both "Private" and "Public" are checked
4. If Node.js is not listed, click "Allow another app..." and add Node.js

**Or use PowerShell (run as Administrator):**
```powershell
New-NetFirewallRule -DisplayName "Node.js Backend" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### 5. Test Backend Accessibility

From your **physical device's browser** (or using a network tool), try to access:
```
http://YOUR_IP:3000/health
```

If this doesn't work, the device cannot reach your backend.

### 6. Backend Server Configuration

Ensure your backend server is listening on all interfaces (0.0.0.0), not just localhost:

In `backend/src/server.ts`, verify:
```typescript
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Day Party API server running on port ${PORT}`);
});
```

The `'0.0.0.0'` is important - it allows connections from other devices on the network.

### 7. Alternative: Use Azure VM Backend

If local development is problematic, you can use the Azure VM backend:

1. Edit `day_party_flutter/lib/core/api_client.dart`
2. Change `_useAzureVm` to `true`:
   ```dart
   static const bool _useAzureVm = true;
   ```
3. Rebuild the app

This will connect to `https://dayparty.work.gd/api` instead of your local backend.

### 8. Check Logs

The app now includes detailed logging. Check the Flutter console/logs for:
- The base URL being used
- Connection attempts
- Detailed error messages

### Common Issues

**Issue:** "Connection timeout" error
- **Solution:** Backend not running, wrong IP, or firewall blocking

**Issue:** "Connection refused"
- **Solution:** Backend not listening on 0.0.0.0, or wrong port

**Issue:** "Network unreachable"
- **Solution:** Devices not on same network, or IP address is wrong

**Issue:** Works on emulator but not physical device
- **Solution:** Emulator uses `10.0.2.2` (special Android emulator IP) for app API calls, but OAuth callbacks require ADB reverse port forwarding (`adb reverse tcp:3000 tcp:3000`). Physical device needs your actual network IP address. See `EMULATOR_SETUP.md` for emulator port forwarding setup.

### Quick Test Commands

**On development machine:**
```powershell
# Start backend (if not running)
cd backend ; npm run dev

# Check if port 3000 is listening
netstat -ano | findstr :3000

# Test health endpoint locally
curl http://localhost:3000/health
```

**On physical device (using browser or network tool):**
```
http://YOUR_IP:3000/health
```

If the health endpoint works from the device's browser, the Flutter app should also work.

