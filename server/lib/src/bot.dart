import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

import 'uno/uno_bot.dart';

/// Telegram bot: shaxsiy xabarda /start ga javob beradi va Mini App tugmasini
/// ko'rsatadi, guruhlarda esa UNO o'yinini olib boradi.
///
/// Webhook ishlatiladi: Telegram xabarni serverga yuboradi
/// (Render'da uxlab qolgan server ham shu so'rov bilan uyg'onadi).
class TelegramBot {
  final String token;

  /// Ilovaning ochiq manzili (Render: RENDER_EXTERNAL_URL)
  final String publicUrl;

  /// Guruhlardagi UNO (bot nomi ma'lum bo'lsa).
  late final UnoBot? uno;

  TelegramBot({required this.token, required this.publicUrl, String? botUsername}) {
    uno = botUsername == null ? null : UnoBot(api: _call, botUsername: botUsername);
  }

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
      'allowed_updates': ['message', 'callback_query'],
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
    // Guruhlarda — UNO buyruqlari
    await _call('setMyCommands', {
      'scope': {'type': 'all_group_chats'},
      'commands': [
        {'command': 'start_uno', 'description': 'UNO o\'yinini ochish'},
        {'command': 'start', 'description': 'Yig\'ilganlar bilan UNO\'ni boshlash'},
        {'command': 'leave_uno', 'description': 'O\'yindan chiqish'},
        {'command': 'stop_uno', 'description': 'O\'yinni to\'xtatish'},
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
      final callback = update['callback_query'] as Map<String, dynamic>?;
      if (callback != null) {
        await uno?.onCallback(callback);
      } else if (msg != null) {
        final type = (msg['chat'] as Map?)?['type'];
        if (type == 'group' || type == 'supergroup') {
          await uno?.onGroupMessage(msg);
        } else {
          await _onMessage(msg);
        }
      }
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
        "• «O'ynash» tugmasini bosing — o'yinni tanlang va kompyuterga qarshi o'ynang\n"
        "• 🃏 <b>UNO</b> — botni guruhga qo'shing va /start_uno yozing. "
        "Kartalaringiz shu yerga, shaxsiy xabarga keladi",
      );
      return;
    }

    // Telegram ID ni bilish (admin qilish uchun)
    if (text.startsWith('/id')) {
      final id = (msg['from'] as Map?)?['id'];
      await _call('sendMessage', {
        'chat_id': chatId,
        'text': 'Sizning Telegram ID: <code>$id</code>',
        'parse_mode': 'HTML',
      });
      return;
    }

    // Guruhdagi UNO uchun bot bilan suhbat ochildi
    if (text == '/start uno') {
      await _send(
        chatId,
        "✅ Tayyor! Endi guruhga qayting va «✋ Qo'shilish» ni bosing.\n"
        "UNO kartalaringiz shu yerga keladi 🃏",
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
