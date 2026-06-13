#!/bin/bash
set -e

cd flutter_app

echo "Installing Flutter..."
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git $HOME/flutter --depth 1
fi
export PATH="$PATH:$HOME/flutter/bin"
flutter config --enable-web

echo "Getting Flutter packages..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Output directory ready at build/web"
ls -la build/web/
