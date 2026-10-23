import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

/// Telegram qanday imzolasa, xuddi shunday initData yasaydi.
String signedInitData(String token, Map<String, String> fields) {
  final keys = fields.keys.toList()..sort();
  final dcs = keys.map((k) => '$k=${fields[k]}').join('\n');
  final secret =
      Hmac(sha256, utf8.encode('WebAppData')).convert(utf8.encode(token));
  final hash = Hmac(sha256, secret.bytes).convert(utf8.encode(dcs));
  return Uri(queryParameters: {...fields, 'hash': hash.toString()}).query;
}

void main() {
  const token = '123456:TEST-token';
  final now = DateTime.now();
  final fields = {
    'auth_date': '${now.millisecondsSinceEpoch ~/ 1000}',
    'query_id': 'AAE',
    'user': jsonEncode({'id': 42, 'first_name': 'Ali', 'last_name': 'Valiyev'}),
  };

  group('Telegram initData', () {
    test("to'g'ri imzo qabul qilinadi", () {
      final user = validateInitData(signedInitData(token, fields), token);
      expect(user?.id, 42);
      expect(user?.name, 'Ali Valiyev');
    });

    test("soxta imzo rad etiladi", () {
      final data = signedInitData('999:other', fields);
      expect(validateInitData(data, token), isNull);
    });

    test("o'zgartirilgan ism rad etiladi", () {
      final data = signedInitData(token, fields)
          .replaceAll('Ali', 'Vali');
      expect(validateInitData(data, token), isNull);
    });

    test('eskirgan initData rad etiladi', () {
      final old = {
        ...fields,
        'auth_date':
            '${now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000}',
      };
      expect(validateInitData(signedInitData(token, old), token), isNull);
    });
  });

  group("O'yinlar", () {
    late Store db;
    late Map<String, Handler> h;
    late Ctx host, guest;

    setUp(() {
      db = Store();
      h = {...roomHandlers(), ...gameHandlers()};
      host = Ctx(db, 'tg1', 'Ali');
      guest = Ctx(db, 'tg2', 'Vali');
    });

    String startGame(String game) {
      final room = h['room.create']!(host, {}) as String;
      expect(h['room.join']!(guest, {'code': room}), isTrue);
      final gameCode =
          h['room.propose']!(host, {'code': room, 'game': game}) as String;
      h['room.accept']!(guest, {'code': room});
      expect(db.get('rooms/$room')!['gameInvite']['response'], 'accepted');
      return gameCode;
    }

    test("xonaga uchinchi odam kira olmaydi", () {
      final room = h['room.create']!(host, {}) as String;
      h['room.join']!(guest, {'code': room});
      expect(h['room.join']!(Ctx(db, 'tg3', 'Sami'), {'code': room}), isFalse);
    });

    test('X-O: navbat va band katak tekshiriladi', () {
      final code = startGame('tictactoe');
      h['ttt.move']!(guest, {'code': code, 'index': 0}); // navbat X da
      expect(db.get('games/$code')!['board'][0], '');
      h['ttt.move']!(host, {'code': code, 'index': 0});
      h['ttt.move']!(guest, {'code': code, 'index': 0}); // band
      final d = db.get('games/$code')!;
      expect(d['board'][0], 'X');
      expect(d['currentTurn'], 'O');
    });

    test("Shashka: qoidaga zid yurish rad etiladi", () {
      final code = startGame('checkers');
      // 40 (5-qator, 0-ustun) dagi oq dona orqaga yura olmaydi
      expect(
        () => h['checkers.move']!(host, {'code': code, 'from': 40, 'to': 49}),
        throwsA(isA<GameError>()),
      );
      h['checkers.move']!(host, {'code': code, 'from': 40, 'to': 33});
      expect(db.get('checkers/$code')!['currentTurn'], 'b');
    });

    test("Viktorina: ball serverda hisoblanadi, ikki marta javob yo'q", () {
      final code = startGame('quiz');
      h['quiz.start']!(host, {'code': code});
      final q = (db.get('quiz_rooms/$code')!['questions'] as List)[0] as Map;
      final correct = q['c'] as int;
      h['quiz.answer']!(guest, {'code': code, 'index': correct});
      h['quiz.answer']!(guest, {'code': code, 'index': correct});
      final score = db.get('quiz_rooms/$code')!['players']['tg2']['score'];
      expect(score, inInclusiveRange(1400, 1500));

      h['quiz.next']!(host, {'code': code, 'current': 0});
      h['quiz.next']!(host, {'code': code, 'current': 0}); // takror
      expect(db.get('quiz_rooms/$code')!['currentQuestion'], 1);
    });

    test("So'z topish: yulduz yetmasa harf ochilmaydi", () {
      final code = startGame('wordpuzzle');
      expect(h['wp.reveal']!(host, {'code': code}), isFalse);
      host.addStars('tg1', 1);
      expect(h['wp.reveal']!(host, {'code': code}), isTrue);
      expect(db.get('users/tg1')!['stars'], 0);
      expect(db.get('word_puzzle/$code')!['revealedLetters'], hasLength(1));
    });

    test("Begona odam o'yinga yura olmaydi", () {
      final code = startGame('tictactoe');
      expect(
        () => h['ttt.move']!(Ctx(db, 'tg9', 'X'), {'code': code, 'index': 1}),
        throwsA(isA<GameError>()),
      );
    });
  });
}
