#!/usr/bin/env bash
# Start postgres + API (docker), then the Flutter web app on :5000.
# Usage: ./dev.sh            SEED_DEMO=true ./dev.sh
set -euo pipefail
cd "$(dirname "$0")"

docker compose up -d --build --wait postgres api

cd mobile
flutter pub get
# web-server: no Chrome needed, open http://localhost:5000 in any browser
flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:4000/api/v1
