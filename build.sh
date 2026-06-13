#!/bin/bash
set -e

API_BASE_URL="${API_BASE_URL:-https://faceinsight-y0sc.onrender.com/api/v1}"
WS_BASE_URL="${WS_BASE_URL:-wss://faceinsight-y0sc.onrender.com/ws}"

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
flutter build web --release \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="WS_BASE_URL=$WS_BASE_URL"

echo "Done!"
ls -la build/web/