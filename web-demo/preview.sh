#!/usr/bin/env bash
# نسخه وب DEMO — تست و نمایش مشتری (بدون SMS واقعی)
cd "$(dirname "$0")"
PORT="${1:-8090}"

if curl -s -o /dev/null --max-time 2 "http://localhost:${PORT}/"; then
  echo "Already serving: http://localhost:${PORT}/"
  exit 0
fi

echo "Web DEMO: http://localhost:${PORT}/"
echo "SMS is FAKE — customer preview / UI test only."
python -m http.server "$PORT"
