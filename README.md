# Oyinim

Do'stlar bilan onlayn o'ynash uchun Flutter + Firebase ilovasi: krestik-nolik, shashka, viktorina, Ha/Yo'q, so'z topish, so'z aralash, guruh va shaxsiy chatlar.

Ilova ikki ko'rinishda ishlaydi, ikkalasi bitta Firebase bazasidan foydalanadi:
- **Android ilova**
- **Telegram Mini App** (Flutter web)

## Ishga tushirish

```bash
flutter pub get
flutter run                 # Android
flutter run -d chrome       # Veb (brauzerda)
```

## Telegram Mini App

1. **Firebase veb sozlamasi.** Firebase Console → Project settings → Your apps → Web app qo'shing. Bergan `apiKey` va `appId` ni [lib/firebase_options.dart](lib/firebase_options.dart) dagi `web` bo'limiga yozing.
2. **Authorized domains.** Firebase Console → Authentication → Settings → Authorized domains bo'limida `online-game-9f0e5.web.app` borligini tekshiring. Anonymous kirish yoqilgan bo'lishi kerak.
3. **Build va joylash:**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```
   Manzil: `https://online-game-9f0e5.web.app`
4. **Bot.** @BotFather'da:
   - `/newbot`: bot yarating.
   - `/newapp`: botni tanlang, URL sifatida hosting manzilini bering, qisqa nom (masalan `play`) kiriting.
   - Bot username va qisqa nomni [lib/telegram/telegram_config.dart](lib/telegram/telegram_config.dart) ga yozing.
5. **Do'stni chaqirish havolasi:** `https://t.me/<bot>/<app>?startapp=XONAKODI`. Do'st havolani bossa, to'g'ridan-to'g'ri xonaga kiradi.

Telegram ichida login ekrani chiqmaydi: foydalanuvchi Telegram ismi bilan avtomatik kiritiladi.
