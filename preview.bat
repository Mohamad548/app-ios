@echo off
rem ------------------------------------------------------------------
rem  Local web preview of the SIM800 Control UI (design preview only).
rem  SMS cannot be sent from the browser; use the Android APK for that.
rem ------------------------------------------------------------------
setlocal
cd /d "%~dp0"

if not exist "build\web\index.html" (
  echo Web preview is not built yet. Run:
  echo    flutter build web --release --no-web-resources-cdn
  pause
  exit /b 1
)

rem Already serving? Just open the browser.
curl -s -o NUL --max-time 2 http://localhost:8080/ >nul 2>nul
if not errorlevel 1 (
  start "" "http://localhost:8080/"
  exit /b 0
)

where py >nul 2>nul
if errorlevel 1 (
  echo Python launcher "py" not found. Install Python or serve build\web with any static server.
  pause
  exit /b 1
)

cd /d "%~dp0build\web"
start "SIM800 preview server" /min py -m http.server 8080
timeout /t 2 >nul
start "" "http://localhost:8080/"

echo.
echo Preview: http://localhost:8080/
echo To stop it, close the minimized "SIM800 preview server" window.
timeout /t 4 >nul
