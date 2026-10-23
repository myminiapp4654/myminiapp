import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:oyinim_server/oyinim_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

/// Muhit o'zgaruvchilari (Render'da Environment bo'limida beriladi):
///   PORT            — Render o'zi beradi (standart 8080)
///   BOT_TOKEN       — @BotFather bergan token (majburiy)
///   APP_SHORT_NAME  — /newapp da berilgan qisqa nom (masalan: play)
///   DEV_LOGIN       — true bo'lsa brauzerda Telegram'siz test qilish mumkin
///   WEB_DIR         — Flutter web build papkasi
///   DATA_DIR        — users.json saqlanadigan papka
///   PUBLIC_URL      — ilovaning ochiq manzili (Render'da RENDER_EXTERNAL_URL o'zi beriladi)
Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final botToken = env['BOT_TOKEN'] ?? '';
  final devLogin = (env['DEV_LOGIN'] ?? '').toLowerCase() == 'true';
  final appShortName = env['APP_SHORT_NAME'] ?? '';
  final webDir = env['WEB_DIR'] ?? '../build/web';
  final dataDir = env['DATA_DIR'] ?? 'data';
  final publicUrl = (env['PUBLIC_URL'] ?? env['RENDER_EXTERNAL_URL'] ?? '')
      .replaceAll(RegExp(r'/+$'), '');

  if (botToken.isEmpty) {
    stderr.writeln('DIQQAT: BOT_TOKEN berilmagan — Telegram orqali kirish ishlamaydi');
  }

  final botUsername = await _fetchBotUsername(botToken);
  final store = Store(dataDir: dataDir);
  final hub = Hub(
    db: store,
    handlers: roomHandlers(),
    botToken: botToken,
    devLogin: devLogin,
    botUsername: botUsername,
    appShortName: appShortName,
  );

  // /start ga javob beradigan bot (ochiq manzil ma'lum bo'lsa)
  final bot = botToken.isNotEmpty && publicUrl.startsWith('https://')
      ? TelegramBot(token: botToken, publicUrl: publicUrl)
      : null;

  final wsHandler = webSocketHandler((ws, _) => hub.handle(ws),
      pingInterval: const Duration(seconds: 25));

  final hasWeb = Directory(webDir).existsSync();
  final staticHandler = hasWeb
      ? createStaticHandler(webDir, defaultDocument: 'index.html')
      : null;
  final indexFile = File('$webDir/index.html');

  FutureOr<Response> handler(Request req) async {
    final path = req.url.path;
    if (path == 'ws') return wsHandler(req);
    if (bot != null && path == bot.webhookPath && req.method == 'POST') {
      return bot.handle(req);
    }
    if (path == 'health') {
      return Response.ok(
        jsonEncode({
          'ok': true,
          'online': hub.onlineCount,
          'docs': store.docCount,
          'bot': botUsername,
        }),
        headers: {'content-type': 'application/json'},
      );
    }
    if (staticHandler == null) {
      return Response.ok('Oyinim server ishlayapti (web build topilmadi)');
    }

    final res = await staticHandler(req);
    // Noma'lum sahifa bo'lsa — ilovaning o'zini qaytaramiz
    if (res.statusCode == 404 && !path.contains('.') && indexFile.existsSync()) {
      return Response.ok(indexFile.openRead(), headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-cache',
      });
    }
    if (path.isEmpty ||
        path == 'index.html' ||
        path == 'flutter_bootstrap.js' ||
        path == 'flutter_service_worker.js' ||
        path == 'version.json') {
      return res.change(headers: {'cache-control': 'no-cache'});
    }
    return res;
  }

  final pipeline =
      const Pipeline().addMiddleware(_logErrors()).addHandler(handler);
  final server = await io.serve(pipeline, InternetAddress.anyIPv4, port);
  server.autoCompress = true;
  stdout.writeln('Oyinim server: http://localhost:${server.port}'
      '${botUsername != null ? '  (bot: @$botUsername)' : ''}'
      '${devLogin ? '  [DEV_LOGIN yoqilgan]' : ''}');

  Future<void> shutdown() async {
    stdout.writeln("To'xtatilmoqda...");
    store.dispose();
    await hub.closeAll();
    await server.close(force: true);
    exit(0);
  }

  // Server tinglay boshlagandan keyin botni sozlaymiz
  if (bot != null) {
    unawaited(bot.setup());
  } else if (botToken.isNotEmpty) {
    stderr.writeln("PUBLIC_URL noma'lum — bot /start ga javob bermaydi");
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => shutdown());
  }
}

Middleware _logErrors() => (inner) => (req) async {
      try {
        return await inner(req);
      } catch (e, st) {
        stderr.writeln('HTTP xato ${req.url}: $e\n$st');
        return Response.internalServerError();
      }
    };

/// Bot username'ini Telegram'dan oladi (do'stga havola yasash uchun).
Future<String?> _fetchBotUsername(String token) async {
  if (token.isEmpty) return null;
  try {
    final res = await http
        .get(Uri.parse('https://api.telegram.org/bot$token/getMe'))
        .timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['result'] as Map?)?['username'] as String?;
  } catch (e) {
    stderr.writeln("Bot ma'lumoti olinmadi: $e");
    return null;
  }
}
