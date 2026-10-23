# Oyinim: Flutter web (Telegram Mini App) + Dart o'yin serveri, bitta konteynerda.
# Render shu faylni o'zi build qiladi (render.yaml ga qarang).

# ---------- 1. Flutter web build ----------
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /app

# Avval faqat paket fayllari — kesh yaxshi ishlashi uchun
COPY pubspec.yaml pubspec.lock ./
COPY packages/ packages/
RUN flutter pub get

COPY lib/ lib/
COPY web/ web/
COPY assets/ assets/
COPY analysis_options.yaml ./
RUN flutter build web --release --no-wasm-dry-run

# ---------- 2. Dart server build ----------
FROM dart:stable AS server
WORKDIR /app

COPY packages/ packages/
COPY server/pubspec.yaml server/pubspec.lock server/
RUN cd server && dart pub get

COPY server/ server/
RUN cd server && dart compile exe bin/server.dart -o /app/oyinim-server
RUN mkdir -p /app/data

# ---------- 3. Ishga tushirish (kichik image) ----------
FROM scratch
COPY --from=server /runtime/ /
COPY --from=server /app/oyinim-server /app/oyinim-server
COPY --from=server /app/data /data
COPY --from=web /app/build/web /app/web

ENV WEB_DIR=/app/web
ENV DATA_DIR=/data
EXPOSE 8080
CMD ["/app/oyinim-server"]
