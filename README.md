# Oyinim — Telegram Mini App

Telegram ichida do'stlar bilan o'ynash uchun Mini App. Hozircha asos: Telegram orqali kirish va 2 kishilik xonalar. O'yinlar keyin qo'shiladi (oldingi versiyasi `games-before-removal` tegida).

- **Ilova:** Flutter web, [lib/](lib/)
- **Server:** Dart + WebSocket, [server/](server/). Telegram foydalanuvchisini bot tokeni orqali tasdiqlaydi, botda `/start` ga javob beradi.

Firebase ishlatilmaydi.

## Render'ga joylash (bir marta)

1. @BotFather'da `/newbot` bilan bot yarating va **token**ni oling.
2. [render.com](https://render.com) → **New → Blueprint** → shu GitHub repo'ni tanlang. Render `render.yaml`ni o'qiydi.
3. So'ralganda kiriting:
   - `BOT_TOKEN`: BotFather bergan token
   - `APP_SHORT_NAME`: hozircha bo'sh qoldiring
4. Deploy tugagach, sizga `https://oyinim-xxxx.onrender.com` manzili beriladi.
5. @BotFather'da:
   - `/newapp`: botni tanlang, URL sifatida Render manzilini bering, qisqa nom kiriting (masalan `play`).
   - Shu qisqa nomni Render → Environment → `APP_SHORT_NAME` ga yozing.
   - Ixtiyoriy: `/mybots` → Bot Settings → Menu Button → Render manzili.

Shundan keyin `telegram-mini-app` branch'iga har bir `git push` qilinganda Render o'zi qayta deploy qiladi.

> Render'ning bepul tarifida server 15 daqiqa ishlatilmasa "uxlaydi", keyingi ochilish ~1 daqiqa kutadi. Yulduzlar va darajalar server qayta ishga tushganda yo'qolishi mumkin (bepul tarifda doimiy disk yo'q).

## Lokal ishga tushirish

```bash
flutter build web
cd server
DEV_LOGIN=true WEB_DIR=../build/web dart run bin/server.dart
# brauzerda: http://localhost:8080  (test rejimi: ism bilan kirish)
```

Ikki o'yinchini sinash uchun ikkita brauzer oynasini oching (biri inkognito rejimda).

## Testlar

```bash
flutter test
cd server && dart test  # server: Telegram imzosi, xonalar, WebSocket
```
