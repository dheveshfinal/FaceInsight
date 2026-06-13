#!/bin/bash
set -e

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 || true
export PATH="$PATH:$(pwd)/flutter/bin"
flutter config --enable-web

echo "Getting Flutter packages..."
cd flutter_app
flutter pub get

echo "Building Flutter Web..."
flutter build web --release \
  --dart-define API_BASE_URL=$API_BASE_URL \
  --dart-define WS_BASE_URL=$WS_BASE_URL

echo "Build complete!"
