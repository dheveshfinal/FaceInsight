#!/bin/bash
set -e

# Get API URLs from environment or use defaults
API_BASE_URL="${API_BASE_URL:-http://localhost:8000/api/v1}"
WS_BASE_URL="${WS_BASE_URL:-ws://localhost:8000/ws}"

echo "Installing Flutter..."
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git $HOME/flutter --depth 1 -b 3.44.2
fi
export PATH="$PATH:$HOME/flutter/bin"
sed -i 's/if \[ "$(id -u)" -eq 0 \]/if false/' $HOME/flutter/bin/flutter
flutter config --enable-web

echo "Getting Flutter packages..."
cd flutter_app
flutter pub get

echo "Building Flutter Web..."
echo "API_BASE_URL: $API_BASE_URL"
echo "WS_BASE_URL: $WS_BASE_URL"
flutter build web --release \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="WS_BASE_URL=$WS_BASE_URL"

echo "Done!"
ls -la build/web/