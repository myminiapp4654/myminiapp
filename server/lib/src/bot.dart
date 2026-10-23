import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

/// Telegram bot: /start ga javob beradi va Mini App tugmasini ko'rsatadi.
///
/// Webhook ishlatiladi: Telegram xabarni serverga yuboradi
/// (Render'da uxlab qolgan server ham shu so'rov bilan uyg'onadi).
class TelegramBot {
  final String token;

  /// Ilovaning ochiq manzili (Render: RENDER_EXTERNAL_URL)
  final String publicUrl;

  TelegramBot({required this.token, required this.publicUrl});

  /// Webhook manzilini taxmin qilib bo'lmasligi uchun tokendan yasalgan maxfiy qism.
  late final String secret =
      sha256.convert(utf8.encode('oyinim-webhook:$token')).toString().substring(0, 32);

  String get webhookPath => 'tg/$secret';

  Uri _api(String method) => Uri.parse('https://api.telegram.org/bot$token/$method');

  Future<Map<String, dynamic>?> _call(String method, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(_api(method),
              headers: {'content-type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] != true) {
        stderr.writeln('Telegram $method: ${data['description']}');
      }
      return data;
    } catch (e) {
      stderr.writeln('Telegram $method xato: $e');
      return null;
    }
  }

  /// Server ishga tushganda: webhook, menyu tugmasi va buyruqlarni sozlaydi.
  Future<void> setup() async {
    await _call('setWebhook', {
      'url': '$publicUrl/$webhookPath',
      'secret_token': secret,
      'allowed_updates': ['message'],
      'drop_pending_updates': false,
    });
    await _call('setChatMenuButton', {
      'menu_button': {
        'type': 'web_app',
        'text': "O'ynash",
        'web_app': {'url': publicUrl},
      },
    });
    await _call('setMyCommands', {
      'commands': [
        {'command': 'start', 'description': "O'yinni boshlash"},
        {'command': 'help', 'description': "Qanday o'ynaladi"},
      ],
    });
    stdout.writeln('Telegram bot sozlandi: $publicUrl');
  }

  /// Telegram'dan kelgan webhook so'rovi.
  Future<Response> handle(Request req) async {
    if (req.headers['x-telegram-bot-api-secret-token'] != secret) {
      return Response.forbidden('');
    }
    try {
      final update = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final msg = update['message'] as Map<String, dynamic>?;
      if (msg != null) await _onMessage(msg);
    } catch (e) {
      stderr.writeln('Webhook xato: $e');
    }
    // Telegram qayta yubormasligi uchun har doim 200
    return Response.ok('');
  }

  Future<void> _onMessage(Map<String, dynamic> msg) async {
    final chat = msg['chat'] as Map<String, dynamic>?;
    if (chat == null || chat['type'] != 'private') return;
    final chatId = chat['id'];
    final text = (msg['text'] as String? ?? '').trim();
    final name = (msg['from'] as Map?)?['first_name'] as String? ?? '';

    if (text.startsWith('/help')) {
      await _send(
        chatId,
        "🎮 <b>Qanday o'ynaladi</b>\n\n"
        "1. «O'ynash» tugmasini bosing\n"
        "2. Xona oching\n"
        "3. ✈ tugmasi bilan do'stingizni chaqiring\n"
        "4. O'yin tanlang va o'ynang!\n\n"
        "O'yinlar: X-O, shashka, viktorina, Ha/Yo'q, so'z topish, harflar",
      );
      return;
    }

    // /start va boshqa har qanday xabarga — salom va o'ynash tugmasi
    await _send(
      chatId,
      "Salom${name.isNotEmpty ? ', <b>${_escape(name)}</b>' : ''}! 👋\n\n"
      "Zerikdingizmi? 😏\n"
      "Do'stlaringiz bilan birga o'ynash uchun to'g'ri joydasiz 🎮\n\n"
      "Pastdagi tugmani bosing 👇",
    );
  }

  Future<void> _send(Object chatId, String text) => _call('sendMessage', {
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'HTML',
        'reply_markup': {
          'inline_keyboard': [
            [
              {
                'text': "🎮 O'ynash",
                'web_app': {'url': publicUrl},
              },
            ],
          ],
        },
      });

  static String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
