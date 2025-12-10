@echo off
echo Starting Flutter Web Server on port 8080...
echo.
echo After it starts, manually open: http://localhost:8080
echo.
cd /d "%~dp0"
flutter run -d web-server --web-port=8080 --web-hostname=localhost
pause

