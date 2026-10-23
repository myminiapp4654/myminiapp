#!/usr/bin/env bash
# Render Build Command:  bash render-build.sh
# Hamma narsa oldindan deploy/ papkasida tayyor (tool/prepare_deploy.sh),
# shuning uchun Render'da hech narsa yig'ilmaydi — faqat tekshiramiz.
set -e
test -f deploy/oyinim-server || { echo "deploy/oyinim-server topilmadi: tool/prepare_deploy.sh ni ishga tushiring"; exit 1; }
test -f deploy/web/index.html || { echo "deploy/web topilmadi: tool/prepare_deploy.sh ni ishga tushiring"; exit 1; }
chmod +x deploy/oyinim-server start.sh
echo "Tayyor"
