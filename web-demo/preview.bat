@echo off
rem SIM800 Web DEMO — UI از SmartRelay Asset Kit (بدون SMS واقعی)
setlocal
cd /d "%~dp0"

curl -s -o NUL --max-time 2 http://127.0.0.1:8090/ >nul 2>nul
if not errorlevel 1 (
  start "" "http://127.0.0.1:8090/"
  exit /b 0
)

where py >nul 2>nul
if errorlevel 1 (
  start "" "%~dp0index.html"
  exit /b 0
)

start "SIM800 web-demo" /min py -3 -m http.server 8090
timeout /t 2 >nul
start "" "http://127.0.0.1:8090/"
echo Web DEMO: http://127.0.0.1:8090/
timeout /t 3 >nul
