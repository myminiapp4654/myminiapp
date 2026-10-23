import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../telegram/telegram.dart';

/// Serverdagi hujjat (Firestore'dagi DocumentSnapshot o'rnida).
class Doc {
  final Map<String, dynamic>? _data;
  const Doc(this._data);

  bool get exists => _data != null;
  Map<String, dynamic>? data() => _data;
}

/// Serverdan kelgan xato (masalan, "Xona topilmadi").
class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => message;
}

enum ConnState { connecting, online, offline }

class AppUser {
  final String uid;
  final String name;
  const AppUser(this.uid, this.name);
}

class _Topic {
  final listeners = <StreamController<Doc>>{};
  Doc? last;
  Timer? unsubTimer;
}

/// O'yin serveri bilan WebSocket aloqasi.
///
/// - Uzilsa o'zi qayta ulanadi va kuzatuvlarni tiklaydi
/// - [watch] — hujjatni kuzatish, [call] — o'yin amali
class ServerClient {
  ServerClient._();
  static final ServerClient instance = ServerClient._();

  /// Lokal test uchun: flutter run --dart-define=SERVER_URL=ws://localhost:8080/ws
  static const _overrideUrl = String.fromEnvironment('SERVER_URL');

  final state = ValueNotifier<ConnState>(ConnState.connecting);
  final user = ValueNotifier<AppUser?>(null);

  /// Kirish rad etilsa — sababi (masalan, "Telegram orqali oching").
  final authError = ValueNotifier<String?>(null);

  String? botUsername;
  String appShortName = '';

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _retryTimer;
  int _retry = 0;
  int _nextId = 1;
  bool _started = false;

  Map<String, dynamic>? _authMsg;
  final _pending = <int, Completer<dynamic>>{};
  final _topics = <String, _Topic>{};

  /// Telegram ichida bo'lsa initData bilan kiradi.
  void startWithTelegram(String initData) {
    _authMsg = {'t': 'auth', 'initData': initData};
    _start();
  }

  /// Faqat test uchun (server DEV_LOGIN=true bo'lsa ishlaydi).
  void startWithDevLogin(String name, String devId) {
    _authMsg = {'t': 'auth', 'devName': name, 'devId': devId};
    authError.value = null;
    if (_started) {
      _reconnectNow();
    } else {
      _start();
    }
  }

  String get myUid => user.value?.uid ?? '';
  String get myName => user.value?.name ?? 'Mehmon';

  /// Ulanish manzili (ekranda xato bo'lsa ko'rsatish uchun ham).
  String get serverUrl => _url.toString();

  Uri get _url {
    if (_overrideUrl.isNotEmpty) return Uri.parse(_overrideUrl);
    // Debug rejimda (flutter run / F5) ilova o'z portida ochiladi,
    // server esa lokal 8080 da ishlaydi
    if (kDebugMode) return Uri.parse('ws://localhost:8080/ws');
    final base = Uri.base;
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws',
    );
  }

  void _start() {
    _started = true;
    _connect();
  }

  void _reconnectNow() {
    _retryTimer?.cancel();
    _closeChannel();
    _connect();
  }

  void _connect() {
    state.value = ConnState.connecting;
    try {
      final ch = WebSocketChannel.connect(_url);
      _ch = ch;
      _sub = ch.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
      ch.ready.then((_) {
        if (_ch != ch) return;
        _send(_authMsg!);
      }).catchError((_) {});
    } catch (_) {
      _onDisconnected();
    }
  }

  void _closeChannel() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }

  void _onDisconnected() {
    _closeChannel();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(ServerException('Aloqa uzildi'));
    }
    _pending.clear();
    if (authError.value != null) return; // Kirish rad etilgan — qayta urinmaymiz
    state.value = ConnState.offline;
    _retry++;
    final delay = Duration(seconds: min(30, 1 << min(_retry, 5)));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _connect);
  }

  /// Foydalanuvchi "qayta urinish" ni bossa.
  void retryNow() {
    _retry = 0;
    _reconnectNow();
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _ch?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['t']) {
      case 'authed':
        final u = msg['user'] as Map;
        user.value = AppUser(u['uid'] as String, u['name'] as String);
        botUsername = msg['bot'] as String?;
        appShortName = (msg['app'] as String?) ?? '';
        authError.value = null;
        _retry = 0;
        state.value = ConnState.online;
        // Kuzatuvlarni tiklaymiz
        for (final topic in _topics.keys) {
          _send({'t': 'sub', 'topic': topic});
        }
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(
            const Duration(seconds: 20), (_) => _send({'t': 'ping'}));
      case 'authError':
        authError.value = msg['e'] as String? ?? 'Kirish rad etildi';
        _closeChannel();
        state.value = ConnState.offline;
      case 'doc':
        final topic = msg['topic'] as String?;
        final t = _topics[topic];
        if (t == null) return;
        final d = msg['d'];
        final doc = Doc(d is Map ? Map<String, dynamic>.from(d) : null);
        t.last = doc;
        for (final c in t.listeners.toList()) {
          c.add(doc);
        }
      case 'res':
        final c = _pending.remove(msg['id']);
        if (c == null || c.isCompleted) return;
        if (msg['ok'] == true) {
          c.complete(msg['r']);
        } else {
          c.completeError(ServerException(msg['e'] as String? ?? 'Xatolik'));
        }
    }
  }

  /// Hujjatni kuzatish. Oxirgi qiymat darhol keladi, keyin har o'zgarishda.
  Stream<Doc> watch(String topic) {
    late StreamController<Doc> c;
    c = StreamController<Doc>(
      onListen: () {
        final t = _topics.putIfAbsent(topic, () => _Topic());
        t.unsubTimer?.cancel();
        final first = t.listeners.isEmpty && t.last == null;
        t.listeners.add(c);
        if (t.last != null) c.add(t.last!);
        if (first && state.value == ConnState.online) {
          _send({'t': 'sub', 'topic': topic});
        }
      },
      onCancel: () {
        final t = _topics[topic];
        if (t == null) return;
        t.listeners.remove(c);
        if (t.listeners.isEmpty) {
          // Ekran qayta chizilganda darhol obunani bekor qilmaymiz
          t.unsubTimer = Timer(const Duration(seconds: 10), () {
            if (t.listeners.isNotEmpty) return;
            _topics.remove(topic);
            if (state.value == ConnState.online) {
              _send({'t': 'unsub', 'topic': topic});
            }
          });
        }
      },
    );
    return c.stream;
  }

  /// O'yin amali. Aloqa yo'q bo'lsa, tiklanishini 10 soniya kutadi.
  Future<T?> call<T>(String method, [Map<String, dynamic>? params]) async {
    if (state.value != ConnState.online) {
      await _waitOnline(const Duration(seconds: 10));
    }
    final id = _nextId++;
    final c = Completer<dynamic>();
    _pending[id] = c;
    _send({'t': 'call', 'id': id, 'm': method, 'p': params ?? {}});
    final result = await c.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pending.remove(id);
        throw ServerException('Server javob bermadi');
      },
    );
    return result as T?;
  }

  Future<void> _waitOnline(Duration timeout) {
    if (state.value == ConnState.online) return Future.value();
    final c = Completer<void>();
    void listener() {
      if (state.value == ConnState.online && !c.isCompleted) c.complete();
    }

    state.addListener(listener);
    return c.future.timeout(timeout, onTimeout: () {
      throw ServerException("Server bilan aloqa yo'q");
    }).whenComplete(() => state.removeListener(listener));
  }

  /// Do'stni xonaga chaqirish havolasi.
  String roomInviteLink(String roomCode) {
    final bot = botUsername;
    if (bot == null) return roomCode;
    return appShortName.isEmpty
        ? 'https://t.me/$bot?startapp=$roomCode'
        : 'https://t.me/$bot/$appShortName?startapp=$roomCode';
  }

  /// Telegram ichida bo'lsa — initData bilan avtomatik ulanadi.
  void autoStart() {
    final initData = Telegram.initData;
    if (initData != null) startWithTelegram(initData);
  }
}
