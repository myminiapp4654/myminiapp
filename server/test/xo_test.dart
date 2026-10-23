import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

void main() {
  group('XoRules.winningLine', () {
    List<String> board(int size, Map<int, String> marks) {
      final b = List.filled(size * size, '');
      marks.forEach((i, m) => b[i] = m);
      return b;
    }

    test('3×3: qator, ustun, ikkala diagonal', () {
      expect(XoRules.winningLine(board(3, {0: 'X', 1: 'X', 2: 'X'}), 3, 3, 1),
          [0, 1, 2]);
      expect(XoRules.winningLine(board(3, {1: 'O', 4: 'O', 7: 'O'}), 3, 3, 7),
          [1, 4, 7]);
      expect(XoRules.winningLine(board(3, {0: 'X', 4: 'X', 8: 'X'}), 3, 3, 4),
          [0, 4, 8]);
      expect(XoRules.winningLine(board(3, {2: 'X', 4: 'X', 6: 'X'}), 3, 3, 6),
          [2, 4, 6]);
    });

    test("3×3: aralash belgilar g'alaba emas", () {
      expect(XoRules.winningLine(board(3, {0: 'X', 1: 'O', 2: 'X'}), 3, 3, 2),
          isNull);
    });

    test("10×10: 5 tasi g'alaba, 4 tasi emas, chetdan o'tib ketmaydi", () {
      // 7,8,9 (1-qator oxiri) va 10,11 (2-qator boshi) — qator emas
      expect(
          XoRules.winningLine(
              board(10, {7: 'X', 8: 'X', 9: 'X', 10: 'X', 11: 'X'}), 10, 5, 9),
          isNull);
      final four = {22: 'O', 33: 'O', 44: 'O', 55: 'O'};
      expect(XoRules.winningLine(board(10, four), 10, 5, 44), isNull);
      expect(
          XoRules.winningLine(board(10, {...four, 66: 'O'}), 10, 5, 66),
          [22, 33, 44, 55, 66]);
    });
  });

  group("X-O o'yini (xona orqali)", () {
    late Store db;
    late Map<String, Handler> h;
    late Ctx ali, vali;
    late String room;

    Map<String, dynamic> game() =>
        db.get('rooms/$room')!['game'] as Map<String, dynamic>;
    void move(Ctx c, int i) => h['xo.move']!(c, {'code': room, 'index': i});

    setUp(() {
      db = Store();
      h = roomHandlers();
      ali = Ctx(db, 'tg1', 'Ali');
      vali = Ctx(db, 'tg2', 'Vali');
      room = h['room.create']!(ali, {}) as String;
      h['room.join']!(vali, {'code': room});
    });

    tearDown(() => db.dispose());

    void start({int size = 3}) {
      h['room.invite']!(ali, {
        'code': room,
        'game': 'xo',
        'options': {'size': size},
      });
      h['room.accept']!(vali, {'code': room});
    }

    test("taklif: noto'g'ri o'lcham va yolg'iz o'yinchi rad etiladi", () {
      expect(
          () => h['room.invite']!(ali, {
                'code': room,
                'game': 'xo',
                'options': {'size': 7},
              }),
          throwsA(isA<GameError>()));
      final solo = h['room.create']!(Ctx(db, 'tg3', 'Sami'), {}) as String;
      expect(
          () => h['room.invite']!(Ctx(db, 'tg3', 'Sami'), {
                'code': solo,
                'game': 'xo',
                'options': {'size': 3},
              }),
          throwsA(isA<GameError>()));
    });

    test("taklif qilgan X bo'lib birinchi yuradi, navbat tekshiriladi", () {
      start();
      expect(game()['x'], 'tg1');
      expect(() => move(vali, 0), throwsA(isA<GameError>()));
      move(ali, 0);
      expect(() => move(ali, 1), throwsA(isA<GameError>()));
      expect(() => move(vali, 0), throwsA(isA<GameError>())); // band
      move(vali, 4);
      expect(game()['board'], ['X', '', '', '', 'O', '', '', '', '']);
      expect(game()['lastMove'], 4);
    });

    test("g'alaba: chiziq, hisob, keyin yurib bo'lmaydi", () {
      start();
      for (final (c, i) in [(ali, 0), (vali, 3), (ali, 1), (vali, 4), (ali, 2)]) {
        move(c, i);
      }
      final g = game();
      expect(g['status'], 'finished');
      expect(g['winner'], 'X');
      expect(g['line'], [0, 1, 2]);
      expect(g['score'], {'tg1': 1, 'tg2': 0});
      expect(() => move(vali, 5), throwsA(isA<GameError>()));
    });

    test('durang', () {
      start();
      // X O X / X O O / O X X
      for (final (c, i) in [
        (ali, 0), (vali, 1), (ali, 2), (vali, 4), (ali, 3),
        (vali, 5), (ali, 7), (vali, 6), (ali, 8),
      ]) {
        move(c, i);
      }
      expect(game()['winner'], 'draw');
      expect(game()['draws'], 1);
    });

    test("qayta o'yin: ikkalasi bossa, birinchi navbat almashadi, hisob saqlanadi", () {
      start();
      for (final (c, i) in [(ali, 0), (vali, 3), (ali, 1), (vali, 4), (ali, 2)]) {
        move(c, i);
      }
      h['xo.rematch']!(ali, {'code': room});
      expect(game()['status'], 'finished');
      expect(game()['rematch'], ['tg1']);
      h['xo.rematch']!(vali, {'code': room});
      final g = game();
      expect(g['status'], 'playing');
      expect(g['round'], 2);
      expect(g['x'], 'tg2'); // endi Vali birinchi
      expect(g['score'], {'tg1': 1, 'tg2': 0});
      expect((g['board'] as List).every((x) => x == ''), isTrue);
    });

    test("o'yinni tugatish ikkalasini xonaga qaytaradi", () {
      start();
      h['room.endGame']!(vali, {'code': room});
      final d = db.get('rooms/$room')!;
      expect(d['game'], isNull);
      expect(d['event']['type'], 'ended');
    });

    test("o'yin paytida chiqib ketish: o'yin to'xtaydi, qolganga xabar", () {
      start();
      h['room.leave']!(vali, {'code': room});
      final d = db.get('rooms/$room')!;
      expect(d['game'], isNull);
      expect(d['event'], containsPair('type', 'left'));
      expect(d['event'], containsPair('name', 'Vali'));
    });

    test("onlayn holati va 'mening xonam'", () {
      updatePresence(db, 'tg2', false);
      expect(db.get('rooms/$room')!['players']['tg2']['online'], isFalse);
      expect(h['room.mine']!(vali, {}), room);
      expect(h['room.mine']!(Ctx(db, 'tg9', 'X'), {}), isNull);
    });

    test('yangi xona ochilsa eski xonadan chiqariladi', () {
      final other = h['room.create']!(vali, {}) as String;
      expect((db.get('rooms/$room')!['players'] as Map).containsKey('tg2'),
          isFalse);
      expect(h['room.mine']!(vali, {}), other);
    });

    test('10×10 da 5 tasi bir qatorda yutadi', () {
      start(size: 10);
      expect(game()['winLen'], 5);
      for (var k = 0; k < 4; k++) {
        move(ali, k); // 0..3
        move(vali, 90 + k);
      }
      move(ali, 4);
      expect(game()['winner'], 'X');
      expect(game()['line'], [0, 1, 2, 3, 4]);
    });
  });
}
