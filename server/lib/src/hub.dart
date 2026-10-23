import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'context.dart';
import 'store.dart';
import 'telegram_auth.dart';

class _Session {
  final WebSocketChannel ch;
  String? uid;
  String? name;

  /// haqiqiy yo'l (users/123) -> mijozdagi nomi (me)
  final subs = <String, String>{};

  _Session(this.ch);

  void send(Map<String, dynamic> msg) {
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (_) {}
  }
}

/// WebSocket ulanishlarini boshqaradi:
///   {t:auth}  — kirish (Telegram initData yoki test rejimida ism)
///   {t:sub}   — hujjatni kuzatish, o'zgarsa {t:doc} keladi
///   {t:call}  — o'yin amali, javob {t:res}
class Hub {
  final Store db;
  final Map<String, Handler> handlers;
  final String botToken;
  final bool devLogin;
  final String? botUsername;
  final String appShortName;

  final _sessions = <_Session>{};
  final _watchers = <String, Set<_Session>>{};

  Hub({
    required this.db,
    required this.handlers,
    required this.botToken,
    required this.devLogin,
    required this.botUsername,
    required this.appShortName,
  }) {
    db.addListener(_onDocChanged);
  }

  int get onlineCount => _sessions.length;

  void handle(WebSocketChannel ch) {
    final s = _Session(ch);
    _sessions.add(s);
    ch.stream.listen(
      (raw) => _onMessage(s, raw),
      onDone: () => _drop(s),
      onError: (_) => _drop(s),
      cancelOnError: true,
    );
  }

  void _drop(_Session s) {
    _sessions.remove(s);
    for (final path in s.subs.keys) {
      _watchers[path]?.remove(s);
      if (_watchers[path]?.isEmpty ?? false) _watchers.remove(path);
    }
    s.subs.clear();
  }

  void _onMessage(_Session s, dynamic raw) {
    if (raw is! String || raw.length > 16 * 1024) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['t']) {
      case 'ping':
        s.send({'t': 'pong'});
      case 'auth':
        _auth(s, msg);
      case 'sub':
        _sub(s, msg['topic']);
      case 'unsub':
        _unsub(s, msg['topic']);
      case 'call':
        _call(s, msg);
    }
  }

  void _auth(_Session s, Map<String, dynamic> msg) {
    String? uid;
    String? name;

    final initData = msg['initData'];
    if (initData is String && initData.isNotEmpty) {
      final user = validateInitData(initData, botToken);
      if (user != null) {
        uid = 'tg${user.id}';
        name = user.name;
      }
    } else if (devLogin) {
      // Faqat test uchun (DEV_LOGIN=true): brauzerda Telegram'siz kirish
      final devName = (msg['devName'] as String?)?.trim() ?? '';
      final devId = (msg['devId'] as String?)?.trim() ?? '';
      if (devName.isNotEmpty && devId.isNotEmpty && devId.length <= 40) {
        uid = 'dev_$devId';
        name = devName.length > 30 ? devName.substring(0, 30) : devName;
      }
    }

    if (uid == null || name == null) {
      s.send({
        't': 'authError',
        'e': devLogin
            ? 'Kirish amalga oshmadi'
            : "Ilovani Telegram orqali oching",
      });
      return;
    }

    s.uid = uid;
    s.name = name;

    final path = 'users/$uid';
    final u = db.get(path) ?? {'uid': uid};
    if (u['name'] != name) {
      u['name'] = name;
      db.set(path, u);
    } else if (!db.exists(path)) {
      db.set(path, u);
    }

    s.send({
      't': 'authed',
      'user': {'uid': uid, 'name': name},
      'bot': botUsername,
      'app': appShortName,
    });
  }

  String? _resolve(_Session s, dynamic topic) {
    if (topic is! String || topic.isEmpty || topic.length > 64) return null;
    if (topic == 'me') return s.uid == null ? null : 'users/${s.uid}';
    // Boshqalarning profilini kuzatib bo'lmaydi
    if (topic.startsWith('users/')) return null;
    return topic;
  }

  void _sub(_Session s, dynamic topic) {
    final path = _resolve(s, topic);
    if (path == null) return;
    s.subs[path] = topic as String;
    _watchers.putIfAbsent(path, () => {}).add(s);
    s.send({'t': 'doc', 'topic': topic, 'd': db.get(path)});
  }

  void _unsub(_Session s, dynamic topic) {
    final path = _resolve(s, topic);
    if (path == null) return;
    s.subs.remove(path);
    _watchers[path]?.remove(s);
    if (_watchers[path]?.isEmpty ?? false) _watchers.remove(path);
  }

  void _onDocChanged(String path, Map<String, dynamic>? data) {
    final watchers = _watchers[path];
    if (watchers == null) return;
    for (final s in watchers.toList()) {
      s.send({'t': 'doc', 'topic': s.subs[path], 'd': data});
    }
  }

  void _call(_Session s, Map<String, dynamic> msg) {
    final id = msg['id'];
    void reply(Map<String, dynamic> body) => s.send({'t': 'res', 'id': id, ...body});

    if (s.uid == null) {
      reply({'ok': false, 'e': 'Avval kiring'});
      return;
    }
    final handler = handlers[msg['m']];
    if (handler == null) {
      reply({'ok': false, 'e': "Noma'lum amal"});
      return;
    }
    final params = msg['p'] is Map
        ? Map<String, dynamic>.from(msg['p'] as Map)
        : <String, dynamic>{};
    try {
      final result = handler(Ctx(db, s.uid!, s.name!), params);
      reply({'ok': true, 'r': result});
    } on GameError catch (e) {
      reply({'ok': false, 'e': e.message});
    } catch (e, st) {
      stderr.writeln('Xato ${msg['m']}: $e\n$st');
      reply({'ok': false, 'e': 'Serverda xatolik'});
    }
  }

  Future<void> closeAll() async {
    for (final s in _sessions.toList()) {
      await s.ch.sink.close();
    }
  }
}
