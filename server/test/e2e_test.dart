import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:oyinim_server/oyinim_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// Haqiqiy WebSocket orqali ulanadigan sinov mijozi.
class TestClient {
  final IOWebSocketChannel ch;
  final _inbox = StreamController<Map<String, dynamic>>.broadcast();
  final docs = <String, Map<String, dynamic>?>{};
  int _id = 1;

  TestClient(this.ch) {
    ch.stream.listen((raw) {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      if (m['t'] == 'doc') docs[m['topic'] as String] = m['d'] as Map<String, dynamic>?;
      _inbox.add(m);
    });
  }

  static Future<TestClient> connect(int port) async {
    final ch = IOWebSocketChannel.connect('ws://localhost:$port/ws');
    await ch.ready;
    return TestClient(ch);
  }

  void send(Map<String, dynamic> m) => ch.sink.add(jsonEncode(m));

  Future<Map<String, dynamic>> next(bool Function(Map<String, dynamic>) where) =>
      _inbox.stream.firstWhere(where).timeout(const Duration(seconds: 5));

  Future<Map<String, dynamic>> login(String name, String id) async {
    final f = next((m) => m['t'] == 'authed' || m['t'] == 'authError');
    send({'t': 'auth', 'devName': name, 'devId': id});
    return f;
  }

  Future<dynamic> call(String m, [Map<String, dynamic>? p]) async {
    final id = _id++;
    final f = next((x) => x['t'] == 'res' && x['id'] == id);
    send({'t': 'call', 'id': id, 'm': m, 'p': p ?? {}});
    final res = await f;
    if (res['ok'] != true) throw GameError(res['e'] as String);
    return res['r'];
  }

  Future<Map<String, dynamic>?> watch(String topic) async {
    final f = next((m) => m['t'] == 'doc' && m['topic'] == topic);
    send({'t': 'sub', 'topic': topic});
    return (await f)['d'] as Map<String, dynamic>?;
  }

  /// [topic] shartga mos kelguncha kutadi (boshqa o'yinchining yurishi).
  Future<Map<String, dynamic>?> waitDoc(
      String topic, bool Function(Map<String, dynamic>? d) cond) async {
    if (docs.containsKey(topic) && cond(docs[topic])) return docs[topic];
    final m = await next(
        (m) => m['t'] == 'doc' && m['topic'] == topic && cond(m['d'] as Map<String, dynamic>?));
    return m['d'] as Map<String, dynamic>?;
  }

  Future<void> close() => ch.sink.close();
}

void main() {
  late HttpServer server;
  late Store store;

  Future<HttpServer> start({required bool devLogin}) async {
    store = Store();
    final hub = Hub(
      db: store,
      handlers: roomHandlers(),
      botToken: 'test',
      devLogin: devLogin,
      botUsername: 'oyinim_bot',
      appShortName: 'play',
    );
    return io.serve(webSocketHandler((ws, _) => hub.handle(ws)),
        InternetAddress.loopbackIPv4, 0);
  }

  tearDown(() async {
    store.dispose();
    await server.close(force: true);
  });

  test("Test rejimi o'chiq bo'lsa Telegram'siz kirib bo'lmaydi", () async {
    server = await start(devLogin: false);
    final c = await TestClient.connect(server.port);
    final res = await c.login('Ali', 'a1');
    expect(res['t'], 'authError');
    await c.close();
  });

  test("Ikki o'yinchi: xona real vaqtda yangilanadi", () async {
    server = await start(devLogin: true);
    final ali = await TestClient.connect(server.port);
    final vali = await TestClient.connect(server.port);

    final authed = await ali.login('Ali', 'a1');
    expect(authed['user']['uid'], 'dev_a1');
    expect(authed['bot'], 'oyinim_bot');
    await vali.login('Vali', 'v1');

    // Kirmasdan oldin amal bajarib bo'lmaydi
    final guest = await TestClient.connect(server.port);
    expect(() => guest.call('room.create'), throwsA(isA<GameError>()));

    final room = await ali.call('room.create') as String;
    await ali.watch('rooms/$room');
    expect(await vali.call('room.join', {'code': room}), isTrue);
    await vali.watch('rooms/$room');

    // Ali Valining kirganini real vaqtda ko'radi
    await ali.waitDoc('rooms/$room', (d) => (d!['players'] as Map).length == 2);

    final me = await ali.watch('me');
    expect(me!['name'], 'Ali');

    // Xo'jayin chiqsa xona Valiga o'tadi
    await ali.call('room.leave', {'code': room});
    final r = await vali.waitDoc('rooms/$room', (d) => d!['host'] == 'dev_v1');
    expect((r!['players'] as Map).length, 1);

    await ali.close();
    await vali.close();
    await guest.close();
  });
}
