#!/bin/bash
set -e

echo "Installing Flutter..."
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git $HOME/flutter --depth 1 -b 3.24.0
fi
export PATH="$PATH:$HOME/flutter/bin"
sed -i 's/if \[ "$(id -u)" -eq 0 \]/if false/' $HOME/flutter/bin/flutter
flutter config --enable-web

echo "Getting Flutter packages..."
cd flutter_app
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Done!"
ls -la build/web/