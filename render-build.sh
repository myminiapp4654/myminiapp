#!/usr/bin/env bash
# Render (Node runtime) uchun build: Flutter SDK'ni yuklab, ilova va serverni yig'adi.
# Render Build Command:  bash render-build.sh
# Render Start Command:  ./start.sh
set -euo pipefail

FLUTTER_VERSION="3.41.2"
SDK_DIR="$HOME/flutter-sdk"

if [ ! -x "$SDK_DIR/flutter/bin/flutter" ]; then
  echo ">> Flutter $FLUTTER_VERSION yuklanmoqda..."
  mkdir -p "$SDK_DIR"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$SDK_DIR"
fi
export PATH="$SDK_DIR/flutter/bin:$PATH"
git config --global --add safe.directory "$SDK_DIR/flutter" || true

flutter --version
flutter config --no-analytics >/dev/null

echo ">> Ilova (web) build..."
flutter pub get
flutter build web --release --no-wasm-dry-run

echo ">> Server build..."
cd server
dart pub get
dart compile exe bin/server.dart -o oyinim-server
cd ..

mkdir -p data
echo ">> Tayyor"
