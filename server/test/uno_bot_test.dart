import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

/// Telegram o'rniga: chaqiruvlarni yozib boradi.
class FakeTelegram {
  final calls = <(String, Map<String, dynamic>)>[];
  var _next = 100;

  /// Bot bilan suhbat ochmagan foydalanuvchilar (shaxsiy xabar bormaydi).
  final blocked = <int>{};

  Future<Map<String, dynamic>?> call(String method, Map<String, dynamic> body) async {
    calls.add((method, body));
    if (method == 'sendMessage' && blocked.contains(body['chat_id'])) {
      return {'ok': false, 'description': 'Forbidden: bot can\'t initiate conversation'};
    }
    if (method == 'getChatMember') {
      return {'ok': true, 'result': {'status': 'member'}};
    }
    return {'ok': true, 'result': {'message_id': _next++}};
  }

  List<Map<String, dynamic>> sent(int chatId) => [
        for (final (m, b) in calls)
          if ((m == 'sendMessage' || m == 'editMessageText') && b['chat_id'] == chatId) b,
      ];

  String lastText(int chatId) => sent(chatId).last['text'] as String;

  List<String> answers() => [
        for (final (m, b) in calls)
          if (m == 'answerCallbackQuery') b['text'] as String? ?? '',
      ];

  /// Foydalanuvchining oxirgi shaxsiy xabaridagi tugmalar.
  List<Map<String, dynamic>> buttons(int userId) {
    final msg = sent(userId).lastWhere((b) => b['reply_markup'] != null);
    final rows = (msg['reply_markup'] as Map)['inline_keyboard'] as List;
    return [for (final r in rows) ...(r as List).cast<Map<String, dynamic>>()];
  }
}

const groupId = -1001;

Map<String, dynamic> msg(int userId, String text) => {
      'chat': {'id': groupId, 'type': 'supergroup', 'title': 'Do\'stlar'},
      'from': {'id': userId, 'first_name': 'U$userId'},
      'text': text,
    };

var _cq = 0;
Map<String, dynamic> cb(int userId, String data, {bool inGroup = false}) => {
      'id': 'cq${_cq++}',
      'from': {'id': userId, 'first_name': 'U$userId'},
      'data': data,
      'message': {
        'chat': {'id': inGroup ? groupId : userId},
      },
    };

void main() {
  late FakeTelegram tg;
  late UnoBot bot;

  setUp(() {
    tg = FakeTelegram();
    bot = UnoBot(api: tg.call, botUsername: 'BreakTimeBot', turnTime: const Duration(milliseconds: 300));
  });
  tearDown(() => bot.dispose());

  String lobbyData(String action) {
    final lobby = tg.sent(groupId).firstWhere((b) => b['reply_markup'] != null);
    final first = ((lobby['reply_markup'] as Map)['inline_keyboard'] as List).first as List;
    final gid = (first.first['callback_data'] as String).split(':')[2];
    return 'uno:$action:$gid';
  }

  Future<void> lobbyWith(List<int> users) async {
    await bot.onGroupMessage(msg(users.first, '/start_uno@BreakTimeBot'));
    for (final u in users.skip(1)) {
      await bot.onCallback(cb(u, lobbyData('j'), inGroup: true));
    }
  }

  test("lobbi: ochish, qo'shilish, botga yozmagan odam ogohlantiriladi", () async {
    tg.blocked.add(3);
    await lobbyWith([1, 2]);
    expect(tg.lastText(groupId), contains('1. U1'));
    expect(tg.lastText(groupId), contains('2. U2'));
    expect(tg.lastText(1), contains("qo'shildingiz"));

    await bot.onCallback(cb(3, lobbyData('j'), inGroup: true));
    expect(tg.answers().last, contains('Botni ochish'));
    expect(tg.lastText(groupId), isNot(contains('U3')));

    // Boshqa botga yozilgan buyruq e'tiborsiz
    expect(await bot.onGroupMessage(msg(1, '/start_uno@OtherBot')), isFalse);
  });

  test("faqat ochgan kishi boshlaydi; boshlanganda har kimga kartalar keladi", () async {
    await lobbyWith([1, 2, 4]);
    await bot.onCallback(cb(2, lobbyData('s'), inGroup: true));
    expect(tg.answers().last, contains('Faqat'));

    await bot.onGroupMessage(msg(1, '/start'));
    expect(tg.sent(groupId).any((b) => (b['text'] as String).contains('UNO boshlandi')), isTrue);
    expect(tg.lastText(groupId), contains('Navbat'));
    for (final u in [1, 2, 4]) {
      expect(tg.lastText(u), contains('Kartalaringiz (7)'));
      final cards = tg.buttons(u).where((b) => (b['callback_data'] as String).startsWith('uno:p:'));
      expect(cards.length, 7);
    }
  });

  test("navbatdagi o'yinchi tugma bilan yuradi, boshqasi yura olmaydi", () async {
    await lobbyWith([1, 2]);
    await bot.onGroupMessage(msg(1, '/start'));

    final turn = [1, 2].firstWhere((u) => tg.lastText(u).contains('Sizning navbatingiz'));
    final other = turn == 1 ? 2 : 1;

    // Navbat bo'lmagan o'yinchi karta bossa
    final otherCard = tg.buttons(other).firstWhere((b) => (b['callback_data'] as String).startsWith('uno:p:'));
    await bot.onCallback(cb(other, otherCard['callback_data'] as String));
    expect(tg.answers().last, contains('Navbat sizda emas'));

    // Navbatdagi o'yinchi: mos karta bo'lsa tashlaydi, bo'lmasa karta oladi
    final mine = tg.buttons(turn);
    final playable = mine.where((b) => (b['text'] as String).startsWith('✅')).toList();
    final groupBefore = tg.sent(groupId).length;
    if (playable.isNotEmpty) {
      await bot.onCallback(cb(turn, playable.first['callback_data'] as String));
      if (tg.buttons(turn).any((b) => (b['callback_data'] as String).startsWith('uno:c:'))) {
        // Wild — rang tanlash
        await bot.onCallback(cb(turn, tg.buttons(turn).first['callback_data'] as String));
      }
    } else {
      final draw = mine.firstWhere((b) => b['text'] == '🃏 Karta olish');
      await bot.onCallback(cb(turn, draw['callback_data'] as String));
      final pass = tg.buttons(turn).where((b) => (b['text'] as String).contains("O'tkazish"));
      if (pass.isNotEmpty) await bot.onCallback(cb(turn, pass.first['callback_data'] as String));
    }
    expect(tg.sent(groupId).length, greaterThan(groupBefore));
    expect(tg.lastText(groupId), contains('Navbat'));
  });

  test("vaqt tugasa avtomatik karta olinadi; /stop_uno o'yinni tugatadi", () async {
    await lobbyWith([1, 2]);
    await bot.onGroupMessage(msg(1, '/start'));
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(tg.sent(groupId).any((b) => (b['text'] as String).contains('vaqtida yurmadi')), isTrue);

    await bot.onGroupMessage(msg(2, '/stop_uno'));
    expect(tg.lastText(groupId), contains('Faqat'));
    await bot.onGroupMessage(msg(1, '/stop_uno'));
    expect(tg.lastText(groupId), contains("to'xtatildi"));
    expect(bot.activeTables, 0);
    expect(tg.lastText(1), contains("O'yin tugadi"));
  });

  test("tugagan o'yinning eski tugmalari ishlamaydi", () async {
    await lobbyWith([1, 2]);
    final oldJoin = lobbyData('j');
    await bot.onGroupMessage(msg(1, '/stop_uno'));
    await bot.onCallback(cb(5, oldJoin, inGroup: true));
    expect(tg.answers().last, contains('tugagan'));
  });
}
