# Flutter Web Development Guide

## Running in Your Existing Browser (Instead of New Chrome Window)

By default, `flutter run -d chrome` opens a new Chrome window. To run in your existing browser session:

### Option 1: Use Your Default Browser

```bash
# Use your default browser instead of Chrome
flutter run -d web-server

# Then manually open: http://localhost:XXXXX in your existing browser
# The port will be shown in the terminal output
```

### Option 2: Use Edge (if it's your default)

```bash
flutter run -d edge
```

### Option 3: Use Firefox

```bash
flutter run -d firefox
```

### Option 4: Run Web Server and Open Manually

```bash
# Start the web server
flutter run -d web-server --web-port=8080

# Then open http://localhost:8080 in your existing browser
# This way you can use your logged-in Google session
```

### Option 5: Build and Serve Locally

```bash
# Build for web
flutter build web

# Serve with any local server (Python, Node.js, etc.)
# Python example:
cd build/web
python -m http.server 8080

# Then open http://localhost:8080 in your browser
```

### Recommended Approach for Development

For development with Google Sign-In, use **Option 4**:

```bash
flutter run -d web-server --web-port=8080
```

Then manually open `http://localhost:8080` in your browser where you're already logged into Google. This way:
- ✅ Uses your existing browser session
- ✅ Keeps you logged into Google
- ✅ Hot reload still works
- ✅ No need to sign in every time

### VS Code / Cursor Launch Configuration

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter Web (Server Mode)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "-d",
        "web-server",
        "--web-port=8080"
      ]
    }
  ]
}
```

Then you can:
1. Press F5 or click "Run" 
2. Terminal will show: "Serving at http://localhost:8080"
3. Manually open that URL in your browser

---

## Video Player Web Compatibility

The video player widget has been updated to work on web:
- ✅ Network URLs (http/https) work on all platforms
- ✅ Local file paths show "Video unavailable" on web (expected - files not supported)
- ✅ External video cards (YouTube/Vimeo) work via `ExternalVideoCard` widget

If you see "Video unavailable" on web, check:
1. Is the video URL a network URL (starts with http:// or https://)?
2. Does the video URL have CORS headers allowing your domain?
3. Is the video format supported by the browser (MP4, WebM)?

