#!/usr/bin/env bash
# Render Start Command:  ./start.sh
# deploy/ papkasidagi tayyor server va ilovani ishga tushiradi.
set -e
chmod +x deploy/oyinim-server
export WEB_DIR="${WEB_DIR:-deploy/web}"
export DATA_DIR="${DATA_DIR:-data}"
mkdir -p "$DATA_DIR"
exec ./deploy/oyinim-server
