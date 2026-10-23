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

  group('Xonalar', () {
    late Store db;
    late Map<String, Handler> h;
    late Ctx ali, vali;

    setUp(() {
      db = Store();
      h = roomHandlers();
      ali = Ctx(db, 'tg1', 'Ali');
      vali = Ctx(db, 'tg2', 'Vali');
    });

    tearDown(() => db.dispose());

    test("xonaga uchinchi odam kira olmaydi", () {
      final room = h['room.create']!(ali, {}) as String;
      expect(h['room.join']!(vali, {'code': room}), isTrue);
      expect(h['room.join']!(Ctx(db, 'tg3', 'Sami'), {'code': room}), isFalse);
    });

    test("mavjud bo'lmagan xona", () {
      expect(h['room.join']!(vali, {'code': 'ZZZZZZ'}), isFalse);
    });

    test("xo'jayin chiqsa xona ikkinchisiga o'tadi, oxirgisi chiqsa o'chadi", () {
      final room = h['room.create']!(ali, {}) as String;
      h['room.join']!(vali, {'code': room});
      h['room.leave']!(ali, {'code': room});
      expect(db.get('rooms/$room')!['host'], 'tg2');
      h['room.leave']!(vali, {'code': room});
      expect(db.exists('rooms/$room'), isFalse);
    });
  });
}
