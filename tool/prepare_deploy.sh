#!/usr/bin/env bash
# Render'ga yuborishdan oldin shu kompyuterda ishga tushiring:
#   bash tool/prepare_deploy.sh && git add deploy && git commit -m "deploy" && git push
# Ilova (web) va server (Linux uchun) tayyor holda deploy/ papkasiga yig'iladi.
set -euo pipefail
cd "$(dirname "$0")/.."

echo ">> Ilova (web) build..."
# Eski plagin keshi build'ni buzmasligi uchun
rm -rf .dart_tool/flutter_build
flutter pub get
flutter build web --release --no-wasm-dry-run
rm -rf deploy/web
mkdir -p deploy
cp -r build/web deploy/web

echo ">> Server (Linux x64) build..."
cd server
dart pub get
dart compile exe bin/server.dart --target-os=linux --target-arch=x64 -o ../deploy/oyinim-server
cd ..

echo ">> Tayyor: deploy/ papkasini commit qilib push qiling"
