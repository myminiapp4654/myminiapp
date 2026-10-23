#!/usr/bin/env bash
# Render Start Command:  ./start.sh
export WEB_DIR="${WEB_DIR:-build/web}"
export DATA_DIR="${DATA_DIR:-data}"
exec ./server/oyinim-server
