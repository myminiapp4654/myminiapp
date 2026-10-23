import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'uno_game.dart';

/// Telegram Bot API chaqiruvi: metod nomi va parametrlar -> javob (yoki null).
typedef BotApi = Future<Map<String, dynamic>?> Function(String method, Map<String, dynamic> body);

/// Guruhdagi bitta UNO stoli.
class _Table {
  final int chatId;
  final String title;
  final UnoGame game;

  /// Eski tugmalarni ajratish uchun o'yin raqami.
  final int gid;

  /// Lobbi xabari (qo'shilish tugmalari bilan).
  int? lobbyMessage;

  /// Har bir o'yinchining shaxsiy xabaridagi kartalar xabari.
  final pm = <int, int>{};

  /// Navbat vaqti.
  Timer? timer;

  /// Shaxsiy xabarlarni yangilashda navbat kimda bo'lganini eslab qolamiz.
  int? lastTurnPlayer;

  _Table(this.chatId, this.title, this.game, this.gid);
}

/// Guruhlarda o'ynaladigan UNO.
///
/// Guruhda:  /start_uno — o'yin ochish, tugmalar bilan qo'shilish,
///           /start yoki «Boshlash» — boshlash, /stop_uno — to'xtatish, /leave_uno — chiqish.
/// Shaxsiy xabarda: har bir o'yinchiga kartalari tugmalar ko'rinishida keladi.
class UnoBot {
  final BotApi api;
  final String botUsername;

  /// Navbat uchun vaqt (shundan keyin avtomatik karta olinadi).
  final Duration turnTime;

  /// Ketma-ket shuncha marta vaqtida yurmasa — o'yindan chiqariladi.
  static const maxTimeouts = 3;

  final _tables = <int, _Table>{}; // guruh id -> stol
  final _userTable = <int, int>{}; // foydalanuvchi id -> guruh id
  final _rnd = Random();

  UnoBot({required this.api, required this.botUsername, this.turnTime = const Duration(seconds: 75)});

  String get _pmLink => 'https://t.me/$botUsername?start=uno';

  static String esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _name(Map<String, dynamic>? from) {
    if (from == null) return "O'yinchi";
    final first = from['first_name'] as String? ?? '';
    final last = from['last_name'] as String? ?? '';
    final full = '$first $last'.trim();
    return full.isEmpty ? (from['username'] as String? ?? "O'yinchi") : full;
  }

  static String _mention(UnoPlayer p) => '<a href="tg://user?id=${p.id}">${esc(p.name)}</a>';

  // ================================================================ guruh buyruqlari

  /// Guruhdagi xabar. Buyruq bo'lsa — true.
  Future<bool> onGroupMessage(Map<String, dynamic> msg) async {
    final chat = msg['chat'] as Map<String, dynamic>;
    final chatId = chat['id'] as int;
    final from = msg['from'] as Map<String, dynamic>?;
    if (from == null) return false;
    final userId = from['id'] as int;
    final text = (msg['text'] as String? ?? '').trim();
    if (!text.startsWith('/')) return false;

    // "/start_uno@BotName arg" -> "start_uno"
    var cmd = text.split(RegExp(r'\s+')).first.substring(1).toLowerCase();
    if (cmd.contains('@')) {
      final parts = cmd.split('@');
      if (parts[1] != botUsername.toLowerCase()) return false; // boshqa botga
      cmd = parts[0];
    }

    switch (cmd) {
      case 'start_uno' || 'uno':
        await _openLobby(chatId, chat['title'] as String? ?? 'Guruh', userId, _name(from));
      case 'start':
        final t = _tables[chatId];
        if (t != null && t.game.status == UnoStatus.lobby) {
          await _startGame(t, userId);
        } else if (t == null) {
          await _send(chatId, "UNO o'ynash uchun /start_uno buyrug'ini yuboring 🃏");
        }
      case 'stop_uno':
        await _stop(chatId, userId);
      case 'leave_uno':
        final t = _tables[chatId];
        if (t != null) await _leave(t, userId, _name(from));
      default:
        return false;
    }
    return true;
  }

  Future<void> _openLobby(int chatId, String title, int userId, String name) async {
    final existing = _tables[chatId];
    if (existing != null && existing.game.status != UnoStatus.finished) {
      await _send(chatId, 'Bu guruhda UNO allaqachon ochilgan. /stop_uno — to\'xtatish.');
      return;
    }
    if (_userTable.containsKey(userId)) {
      await _send(chatId, '${esc(name)}, siz boshqa guruhdagi UNO o\'yinidasiz.');
      return;
    }
    final game = UnoGame(ownerId: userId, random: _rnd);
    final t = _Table(chatId, title, game, _rnd.nextInt(1 << 30));
    _tables[chatId] = t;
    if (await _welcomePm(t, userId)) {
      game.join(userId, name);
      _userTable[userId] = chatId;
    }
    final res = await _send(chatId, _lobbyText(t), keyboard: _lobbyKeyboard(t));
    t.lobbyMessage = _messageId(res);
  }

  String _lobbyText(_Table t) {
    final g = t.game;
    final list = g.players.isEmpty
        ? '—'
        : [for (var k = 0; k < g.players.length; k++) '${k + 1}. ${esc(g.players[k].name)}'].join('\n');
    return '🃏 <b>UNO</b> — yangi o\'yin!\n\n'
        'O\'yinchilar (${g.players.length}/${UnoGame.maxPlayers}):\n$list\n\n'
        '«✋ Qo\'shilish» tugmasini bosing. Kartalar shaxsiy xabarda keladi — '
        'agar botga hali yozmagan bo\'lsangiz, avval «🤖 Botni ochish» ni bosing.\n'
        'Kamida ${UnoGame.minPlayers} kishi yig\'ilgach — /start yoki «▶️ Boshlash».';
  }

  Map<String, dynamic> _lobbyKeyboard(_Table t) => {
        'inline_keyboard': [
          [
            {'text': "✋ Qo'shilish", 'callback_data': 'uno:j:${t.gid}'},
            {'text': '🚪 Chiqish', 'callback_data': 'uno:l:${t.gid}'},
          ],
          [
            {'text': '▶️ Boshlash', 'callback_data': 'uno:s:${t.gid}'},
            {'text': '🤖 Botni ochish', 'url': _pmLink},
          ],
        ],
      };

  Future<void> _refreshLobby(_Table t) async {
    final id = t.lobbyMessage;
    if (id == null) return;
    await api('editMessageText', {
      'chat_id': t.chatId,
      'message_id': id,
      'text': _lobbyText(t),
      'parse_mode': 'HTML',
      'reply_markup': _lobbyKeyboard(t),
    });
  }

  /// Shaxsiy xabar yuborib ko'radi: bot bilan suhbat ochilmagan bo'lsa — false.
  Future<bool> _welcomePm(_Table t, int userId) async {
    final res = await api('sendMessage', {
      'chat_id': userId,
      'text': '🃏 Siz «${esc(t.title)}» guruhidagi UNO o\'yiniga qo\'shildingiz.\n'
          'O\'yin boshlanganda kartalaringiz shu yerga keladi.',
      'parse_mode': 'HTML',
    });
    return res?['ok'] == true;
  }

  Future<void> _join(_Table t, int userId, String name, String callbackId) async {
    final g = t.game;
    if (g.status != UnoStatus.lobby) {
      return _answer(callbackId, "O'yin allaqachon boshlangan");
    }
    if (g.player(userId) != null) return _answer(callbackId, "Siz allaqachon o'yindasiz");
    if (_userTable.containsKey(userId)) {
      return _answer(callbackId, "Siz boshqa guruhdagi o'yindasiz", alert: true);
    }
    if (g.players.length >= UnoGame.maxPlayers) return _answer(callbackId, "Joy qolmadi");
    if (!await _welcomePm(t, userId)) {
      return _answer(callbackId,
          "Avval botga shaxsiy xabarda yozing: «🤖 Botni ochish» → Start, keyin qayta bosing.",
          alert: true);
    }
    g.join(userId, name);
    _userTable[userId] = t.chatId;
    await _answer(callbackId, "Qo'shildingiz! ✅");
    await _refreshLobby(t);
  }

  Future<void> _startGame(_Table t, int userId, [String? callbackId]) async {
    final g = t.game;
    if (userId != g.ownerId && g.player(g.ownerId) != null) {
      if (callbackId != null) return _answer(callbackId, "Faqat o'yinni ochgan kishi boshlay oladi");
      return;
    }
    if (g.players.length < UnoGame.minPlayers) {
      const text = "Kamida 2 ta o'yinchi kerak";
      if (callbackId != null) return _answer(callbackId, text);
      await _send(t.chatId, text);
      return;
    }
    if (callbackId != null) await _answer(callbackId, 'Boshlandi!');
    g.start();
    if (t.lobbyMessage != null) {
      await api('editMessageReplyMarkup', {
        'chat_id': t.chatId,
        'message_id': t.lobbyMessage,
        'reply_markup': {'inline_keyboard': []},
      });
    }
    final order = [for (final p in g.players) esc(p.name)].join(' → ');
    await _send(
      t.chatId,
      '🎮 <b>UNO boshlandi!</b> Har kimga ${UnoGame.handSize} tadan karta tarqatildi.\n'
      'Navbat tartibi: $order\n\nKartalaringiz — botning shaxsiy xabarida 👇',
      keyboard: _cardsButton(),
    );
    await _afterMove(t, const []);
  }

  Future<void> _stop(int chatId, int userId) async {
    final t = _tables[chatId];
    if (t == null) return;
    if (userId != t.game.ownerId && !await _isAdmin(chatId, userId)) {
      await _send(chatId, "Faqat o'yinni ochgan kishi yoki guruh admini to'xtata oladi.");
      return;
    }
    await _finish(t, '🛑 UNO to\'xtatildi.');
  }

  Future<bool> _isAdmin(int chatId, int userId) async {
    final res = await api('getChatMember', {'chat_id': chatId, 'user_id': userId});
    final status = (res?['result'] as Map?)?['status'];
    return status == 'administrator' || status == 'creator';
  }

  Future<void> _leave(_Table t, int userId, String name) async {
    final g = t.game;
    final p = g.player(userId);
    if (p == null) return;
    final wasTurn = g.status == UnoStatus.playing && g.current == p;
    g.leave(userId);
    _userTable.remove(userId);
    await _deletePm(t, userId);
    if (g.status == UnoStatus.lobby) {
      await _refreshLobby(t);
      return;
    }
    if (g.status == UnoStatus.finished) {
      await _finish(t, '🚪 ${esc(name)} chiqdi — o\'yinchilar yetmay qoldi.');
      return;
    }
    await _afterMove(t, [UnoEvent('🚪 $name o\'yindan chiqdi')], newTurn: wasTurn);
  }

  // ================================================================ tugmalar

  /// Inline tugma bosildi (guruhda yoki shaxsiy xabarda).
  Future<void> onCallback(Map<String, dynamic> cq) async {
    final id = cq['id'] as String;
    final data = cq['data'] as String? ?? '';
    final from = cq['from'] as Map<String, dynamic>;
    final userId = from['id'] as int;
    if (!data.startsWith('uno:')) return;
    final parts = data.split(':');
    if (parts.length < 3) return _answer(id, '');
    final action = parts[1];
    final gid = int.tryParse(parts[2]) ?? -1;

    // Lobbi tugmalari — guruh xabarida
    if (action == 'j' || action == 'l' || action == 's') {
      final chatId = ((cq['message'] as Map?)?['chat'] as Map?)?['id'] as int?;
      final t = chatId == null ? null : _tables[chatId];
      if (t == null || t.gid != gid) return _answer(id, "Bu o'yin tugagan");
      switch (action) {
        case 'j':
          return _join(t, userId, _name(from), id);
        case 'l':
          if (t.game.player(userId) == null) return _answer(id, "Siz o'yinda emassiz");
          await _answer(id, 'Chiqdingiz');
          return _leave(t, userId, _name(from));
        case 's':
          return _startGame(t, userId, id);
      }
    }

    // O'yin tugmalari — shaxsiy xabarda
    final chatId = _userTable[userId];
    final t = chatId == null ? null : _tables[chatId];
    if (t == null || t.gid != gid || t.game.status != UnoStatus.playing) {
      return _answer(id, "Bu o'yin tugagan");
    }
    final g = t.game;
    final p = g.player(userId)!;
    if (action == 'i') return _answer(id, '');
    if (g.current != p) return _answer(id, '⏳ Navbat sizda emas');
    p.timeouts = 0;

    switch (action) {
      case 'p': // karta tashlash
        final cardId = int.tryParse(parts.length > 3 ? parts[3] : '') ?? -1;
        final card = p.hand.where((c) => c.id == cardId).firstOrNull;
        if (card == null) return _answer(id, '');
        if (!g.playable(p).contains(card)) {
          return _answer(id, g.drawnThisTurn != null
              ? "Faqat olingan kartani tashlash yoki o'tkazish mumkin"
              : '❌ Bu karta stolga mos emas');
        }
        final events = g.play(userId, cardId);
        await _answer(id, card.isWild ? 'Rangni tanlang' : '');
        if (g.pendingWild != null) {
          await _refreshPm(t, p); // rang tanlash tugmalari
          return;
        }
        return _afterMove(t, events, newTurn: true);
      case 'c': // Wild rangini tanlash
        final ci = int.tryParse(parts.length > 3 ? parts[3] : '') ?? -1;
        if (ci < 0 || ci > 3) return _answer(id, '');
        final events = g.chooseColor(userId, UnoColor.values[ci]);
        await _answer(id, '');
        return _afterMove(t, events, newTurn: true);
      case 'd': // karta olish
        final got = g.draw(userId);
        if (got == null) return _answer(id, 'Bu navbatda karta oldingiz');
        await _answer(id, 'Oldingiz: ${got.label}${g.canPlay(got) ? ' — tashlash mumkin!' : ''}');
        if (!g.canPlay(got)) {
          // Mos kelmasa — navbat avtomatik o'tadi
          g.pass(userId);
          return _afterMove(t, [UnoEvent('🃏 ${p.name} karta oldi')], newTurn: true);
        }
        await _send(t.chatId, '🃏 ${esc(p.name)} karta oldi');
        await _refreshPm(t, p);
        _restartTimer(t);
        return;
      case 'x': // o'tkazish
        if (!g.pass(userId)) return _answer(id, '');
        await _answer(id, '');
        return _afterMove(t, [UnoEvent('⏭ ${p.name} navbatini o\'tkazdi')], newTurn: true);
      case 'u': // UNO!
        if (!g.sayUno(userId)) return _answer(id, '"UNO!" faqat 2 ta karta qolganda');
        await _answer(id, '📢 UNO! Endi kartani tashlang', alert: true);
        return _refreshPm(t, p);
    }
    return _answer(id, '');
  }

  // ================================================================ yurishdan keyin

  /// Guruhga xabar, shaxsiy xabarlarni yangilash, taymer, g'alaba.
  Future<void> _afterMove(_Table t, List<UnoEvent> events, {bool newTurn = true}) async {
    final g = t.game;
    if (g.status == UnoStatus.finished) {
      final w = g.winner;
      final lines = [for (final e in events) esc(e.text)];
      if (w != null) {
        final rest = [
          for (final p in g.players)
            if (p != w) '${esc(p.name)} — ${p.hand.length} karta',
        ].join('\n');
        lines.add('\n🏆 <b>${_mention(w)} yutdi!</b>\n$rest');
      }
      await _finish(t, lines.join('\n'));
      return;
    }

    final cur = g.current;
    final dir = g.direction == 1 ? '↻' : '↺';
    final text = [
      for (final e in events) esc(e.text),
      '',
      '🃏 Stolda: <b>${g.top.label}</b>'
          '${g.top.isWild ? ' → ${UnoCard.colorEmoji(g.currentColor)}' : ''}  $dir',
      '👉 Navbat: ${_mention(cur)} (${cur.hand.length} karta)',
    ].join('\n').trim();
    await _send(t.chatId, text, keyboard: _cardsButton());

    // Navbati kelgan o'yinchiga yangi xabar (bildirishnoma keladi), qolganlariga — tahrir
    for (final p in [...g.players]) {
      if (p == cur && (newTurn || t.lastTurnPlayer != p.id)) {
        await _deletePm(t, p.id);
      }
      await _refreshPm(t, p);
    }
    t.lastTurnPlayer = cur.id;
    _restartTimer(t);
  }

  Map<String, dynamic> _cardsButton() => {
        'inline_keyboard': [
          [
            {'text': '🃏 Kartalarim', 'url': 'https://t.me/$botUsername'},
          ],
        ],
      };

  void _restartTimer(_Table t) {
    t.timer?.cancel();
    final gid = t.gid;
    t.timer = Timer(turnTime, () async {
      if (_tables[t.chatId]?.gid != gid || t.game.status != UnoStatus.playing) return;
      final p = t.game.current;
      final events = t.game.timeout();
      if (p.timeouts >= maxTimeouts) {
        // Avval sabab, keyin chiqarish (u o'z navbatida yangi holatni e'lon qiladi)
        events.add(UnoEvent('🚫 ${p.name} $maxTimeouts marta yurmadi — o\'yindan chiqarildi'));
        await _send(t.chatId, esc(events.join('\n')));
        await _leave(t, p.id, p.name);
        return;
      }
      await _afterMove(t, events, newTurn: true);
    });
  }

  Future<void> _finish(_Table t, String text) async {
    t.timer?.cancel();
    t.game.status = UnoStatus.finished;
    for (final p in t.game.players) {
      _userTable.remove(p.id);
      final id = t.pm[p.id];
      if (id != null) {
        await api('editMessageText', {
          'chat_id': p.id,
          'message_id': id,
          'text': "🃏 O'yin tugadi. Guruhga qayting!",
        });
      }
    }
    if (t.lobbyMessage != null && t.game.players.isNotEmpty) {
      await api('editMessageReplyMarkup', {
        'chat_id': t.chatId,
        'message_id': t.lobbyMessage,
        'reply_markup': {'inline_keyboard': []},
      });
    }
    _tables.remove(t.chatId);
    await _send(t.chatId, '$text\n\nYangi o\'yin: /start_uno');
  }

  // ================================================================ shaxsiy xabar

  String _pmText(_Table t, UnoPlayer me) {
    final g = t.game;
    final cur = g.current;
    final others = [
      for (final p in g.players)
        '${p == cur ? '👉 ' : ''}${esc(p.name)}${p == me ? ' (siz)' : ''}: ${p.hand.length}',
    ].join('\n');
    final String status;
    if (cur != me) {
      status = '⏳ Navbat: ${esc(cur.name)}';
    } else if (g.pendingWild != null) {
      status = '🎨 <b>Rangni tanlang</b>';
    } else if (g.drawnThisTurn != null) {
      status = "🟢 <b>Olingan kartani tashlang yoki o'tkazing</b>";
    } else {
      status = '🟢 <b>Sizning navbatingiz!</b>';
    }
    return '🃏 <b>UNO</b> — ${esc(t.title)}\n\n'
        'Stolda: <b>${g.top.label}</b>'
        '${g.top.isWild ? ' → ${UnoCard.colorEmoji(g.currentColor)} ${UnoCard.colorName(g.currentColor)}' : ''}\n'
        '$status\n\n'
        '$others\n\n'
        'Kartalaringiz (${me.hand.length}):';
  }

  Map<String, dynamic> _pmKeyboard(_Table t, UnoPlayer me) {
    final g = t.game;
    final myTurn = g.current == me;
    final rows = <List<Map<String, dynamic>>>[];

    if (myTurn && g.pendingWild != null) {
      rows.add([
        for (var k = 0; k < 4; k++)
          {
            'text': '${UnoCard.colorEmoji(UnoColor.values[k])} ${UnoCard.colorName(UnoColor.values[k])}',
            'callback_data': 'uno:c:${t.gid}:$k',
          },
      ]);
      return {'inline_keyboard': rows};
    }

    final playable = myTurn ? g.playable(me).toSet() : <UnoCard>{};
    // Mos kartalar oldinda, ✅ belgisi bilan
    final cards = [...me.hand]..sort((a, b) {
        final pa = playable.contains(a) ? 0 : 1, pb = playable.contains(b) ? 0 : 1;
        return pa != pb ? pa - pb : a.sortKey.compareTo(b.sortKey);
      });
    var row = <Map<String, dynamic>>[];
    for (final c in cards) {
      row.add({
        'text': playable.contains(c) ? '✅${c.label}' : c.label,
        'callback_data': 'uno:p:${t.gid}:${c.id}',
      });
      if (row.length == 4) {
        rows.add(row);
        row = [];
      }
    }
    if (row.isNotEmpty) rows.add(row);

    if (myTurn) {
      rows.add([
        if (g.drawnThisTurn == null)
          {'text': '🃏 Karta olish', 'callback_data': 'uno:d:${t.gid}'}
        else
          {'text': "⏭ O'tkazish", 'callback_data': 'uno:x:${t.gid}'},
        if (me.hand.length == 2 && !me.saidUno) {'text': '📢 UNO!', 'callback_data': 'uno:u:${t.gid}'},
      ]);
    }
    return {'inline_keyboard': rows};
  }

  /// O'yinchining shaxsiy xabarini yangilaydi (yo'q bo'lsa — yuboradi).
  Future<void> _refreshPm(_Table t, UnoPlayer p) async {
    final text = _pmText(t, p);
    final keyboard = _pmKeyboard(t, p);
    final id = t.pm[p.id];
    if (id != null) {
      final res = await api('editMessageText', {
        'chat_id': p.id,
        'message_id': id,
        'text': text,
        'parse_mode': 'HTML',
        'reply_markup': keyboard,
      });
      // "message is not modified" ham muvaffaqiyat
      final desc = res?['description'] as String? ?? '';
      if (res?['ok'] == true || desc.contains('not modified')) return;
    }
    final res = await api('sendMessage', {
      'chat_id': p.id,
      'text': text,
      'parse_mode': 'HTML',
      'reply_markup': keyboard,
    });
    final mid = _messageId(res);
    if (mid != null) t.pm[p.id] = mid;
  }

  Future<void> _deletePm(_Table t, int userId) async {
    final id = t.pm.remove(userId);
    if (id != null) await api('deleteMessage', {'chat_id': userId, 'message_id': id});
  }

  // ================================================================ yordamchilar

  Future<Map<String, dynamic>?> _send(int chatId, String text, {Map<String, dynamic>? keyboard}) =>
      api('sendMessage', {
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'HTML',
        'disable_web_page_preview': true,
        'reply_markup': ?keyboard,
      });

  Future<void> _answer(String callbackId, String text, {bool alert = false}) async {
    await api('answerCallbackQuery', {
      'callback_query_id': callbackId,
      if (text.isNotEmpty) 'text': text,
      if (alert) 'show_alert': true,
    });
  }

  static int? _messageId(Map<String, dynamic>? res) =>
      ((res?['result'] as Map?)?['message_id'] as num?)?.toInt();

  /// Testlar uchun: faol stollar soni.
  int get activeTables => _tables.length;

  void dispose() {
    for (final t in _tables.values) {
      t.timer?.cancel();
    }
    stdout.writeln('UNO: ${_tables.length} ta stol yopildi');
  }
}
