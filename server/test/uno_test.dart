import 'dart:math';

import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

/// Ikki o'yinchili, boshlangan o'yin; qo'llar va stol qo'lda beriladi.
UnoGame setup(List<List<UnoCard>> hands, UnoCard top, {int players = 2}) {
  final g = UnoGame(ownerId: 1, random: Random(1));
  for (var k = 0; k < players; k++) {
    g.join(k + 1, 'P${k + 1}');
  }
  g.start();
  // O'yinchilar tartibini tiklaymiz va qo'llarni almashtiramiz
  g.players.sort((a, b) => a.id.compareTo(b.id));
  for (var k = 0; k < players; k++) {
    g.players[k].hand
      ..clear()
      ..addAll(k < hands.length ? hands[k] : [card(UnoColor.green, 5, 900 + k)]);
  }
  g.discardPile
    ..clear()
    ..add(top);
  g.currentColor = top.color;
  g.turn = 0;
  return g;
}

int _id = 500;
UnoCard card(UnoColor c, int n, [int? id]) => UnoCard(id ?? _id++, c, UnoKind.number, n);
UnoCard action(UnoColor c, UnoKind k) => UnoCard(_id++, c, k);

void main() {
  group('Paluba', () {
    test('108 karta: har rangda 25 ta, 4 Wild, 4 Wild+4, id lar takrorlanmaydi', () {
      final d = buildDeck();
      expect(d.length, 108);
      expect(d.map((c) => c.id).toSet().length, 108);
      for (final c in [UnoColor.red, UnoColor.yellow, UnoColor.green, UnoColor.blue]) {
        expect(d.where((x) => x.color == c).length, 25);
        expect(d.where((x) => x.color == c && x.kind == UnoKind.number && x.number == 0).length, 1);
        expect(d.where((x) => x.color == c && x.kind == UnoKind.draw2).length, 2);
      }
      expect(d.where((x) => x.kind == UnoKind.wild).length, 4);
      expect(d.where((x) => x.kind == UnoKind.wild4).length, 4);
    });

    test("boshlash: 7 tadan, birinchi karta raqamli, jami 108 saqlanadi", () {
      for (var seed = 0; seed < 20; seed++) {
        final g = UnoGame(ownerId: 1, random: Random(seed));
        for (var k = 1; k <= 4; k++) {
          g.join(k, 'P$k');
        }
        expect(g.start(), isTrue);
        for (final p in g.players) {
          expect(p.hand.length, 7);
        }
        expect(g.top.kind, UnoKind.number);
        final total = g.drawPile.length + g.discardPile.length + g.players.fold(0, (s, p) => s + p.hand.length);
        expect(total, 108);
      }
    });

    test("1 kishi bilan boshlab bo'lmaydi, 10 tadan ortiq qo'shilmaydi", () {
      final g = UnoGame(ownerId: 1)..join(1, 'A');
      expect(g.start(), isFalse);
      for (var k = 2; k <= 12; k++) {
        g.join(k, 'P$k');
      }
      expect(g.players.length, 10);
      expect(g.join(2, 'takror'), isFalse);
    });
  });

  group('Qoidalar', () {
    test('rang yoki raqam mos bo\'lsa tashlanadi, aks holda yo\'q', () {
      final r7 = card(UnoColor.red, 7), b7 = card(UnoColor.blue, 7), g3 = card(UnoColor.green, 3);
      final g = setup([
        [r7, b7, g3, card(UnoColor.red, 1)],
      ], card(UnoColor.red, 2));
      expect(g.canPlay(r7), isTrue);
      expect(g.canPlay(g3), isFalse);
      expect(g.play(1, g3.id), isEmpty);
      expect(g.play(1, b7.id), isEmpty); // ko'k 7 qizil 2 ga mos emas
      expect(g.play(1, r7.id), isNotEmpty);
      expect(g.currentColor, UnoColor.red);
      expect(g.current.id, 2);
      // Endi qizil 7 ustiga ko'k 7 mos (raqam bir xil)
      expect(g.canPlay(b7), isTrue);
    });

    test("navbatda bo'lmagan o'yinchi tashlay olmaydi", () {
      final c = card(UnoColor.red, 3);
      final g = setup([
        [card(UnoColor.red, 1), card(UnoColor.red, 9)],
        [c, card(UnoColor.red, 4)],
      ], card(UnoColor.red, 2));
      expect(g.play(2, c.id), isEmpty);
    });

    test('Skip: keyingi o\'yinchi o\'tkazib yuboriladi', () {
      final skip = action(UnoColor.red, UnoKind.skip);
      final g = setup([
        [skip, card(UnoColor.red, 1), card(UnoColor.red, 2)],
      ], card(UnoColor.red, 5), players: 3);
      g.play(1, skip.id);
      expect(g.current.id, 3);
    });

    test("Reverse: yo'nalish teskari; 2 kishida — Skip kabi", () {
      final rev = action(UnoColor.red, UnoKind.reverse);
      final g = setup([
        [rev, card(UnoColor.red, 1), card(UnoColor.red, 2)],
      ], card(UnoColor.red, 5), players: 4);
      g.play(1, rev.id);
      expect(g.direction, -1);
      expect(g.current.id, 4);

      final rev2 = action(UnoColor.red, UnoKind.reverse);
      final h = setup([
        [rev2, card(UnoColor.red, 1), card(UnoColor.red, 2)],
      ], card(UnoColor.red, 5));
      h.play(1, rev2.id);
      expect(h.current.id, 1);
    });

    test("+2: keyingi o'yinchi 2 karta oladi va navbati o'tadi", () {
      final d2 = action(UnoColor.red, UnoKind.draw2);
      final g = setup([
        [d2, card(UnoColor.red, 1), card(UnoColor.red, 2)],
      ], card(UnoColor.red, 5), players: 3);
      final before = g.players[1].hand.length;
      g.play(1, d2.id);
      expect(g.players[1].hand.length, before + 2);
      expect(g.current.id, 3);
    });

    test('Wild +4: rang tanlanadi, keyingisi 4 oladi va o\'tkaziladi', () {
      final w4 = UnoCard(_id++, UnoColor.wild, UnoKind.wild4);
      final g = setup([
        [w4, card(UnoColor.red, 1), card(UnoColor.red, 2)],
      ], card(UnoColor.green, 5), players: 3);
      final before = g.players[1].hand.length;
      final events = g.play(1, w4.id);
      expect(events, isNotEmpty);
      expect(g.pendingWild, w4);
      expect(g.current.id, 1); // rang tanlanmaguncha navbat o'tmaydi
      expect(g.draw(1), isNull);
      g.chooseColor(1, UnoColor.blue);
      expect(g.currentColor, UnoColor.blue);
      expect(g.players[1].hand.length, before + 4);
      expect(g.current.id, 3);
    });

    test("karta olish: navbatda bir marta; mos bo'lsa tashlash, bo'lmasa o'tkazish", () {
      final g = setup([
        [card(UnoColor.green, 1), card(UnoColor.green, 2)],
      ], card(UnoColor.red, 5));
      final got = g.draw(1)!;
      expect(g.players[0].hand, contains(got));
      expect(g.draw(1), isNull);
      // Faqat olingan karta tashlanishi mumkin
      expect(g.playable(g.players[0]), g.canPlay(got) ? [got] : isEmpty);
      expect(g.pass(1), isTrue);
      expect(g.current.id, 2);
    });

    test('UNO: aytmasa +2 jarima, aytsa jarimasiz', () {
      final a = card(UnoColor.red, 1), b = card(UnoColor.red, 2);
      final g = setup([
        [a, b],
      ], card(UnoColor.red, 5));
      final events = g.play(1, a.id);
      expect(events.join(), contains('UNO'));
      expect(g.players[0].hand.length, 3); // 1 + 2 jarima

      final c = card(UnoColor.red, 3), d = card(UnoColor.red, 4);
      final h = setup([
        [c, d],
      ], card(UnoColor.red, 5));
      expect(h.sayUno(1), isTrue);
      h.play(1, c.id);
      expect(h.players[0].hand.length, 1);
    });

    test("UNO faqat 2 ta karta qolganda va o'z navbatida", () {
      final g = setup([
        [card(UnoColor.red, 1), card(UnoColor.red, 2), card(UnoColor.red, 3)],
        [card(UnoColor.red, 4), card(UnoColor.red, 6)],
      ], card(UnoColor.red, 5));
      expect(g.sayUno(1), isFalse); // 3 ta karta
      expect(g.sayUno(2), isFalse); // navbat unda emas
    });

    test("oxirgi kartani tashlagan yutadi", () {
      final last = card(UnoColor.red, 9);
      final g = setup([
        [last],
      ], card(UnoColor.red, 5));
      g.play(1, last.id);
      expect(g.status, UnoStatus.finished);
      expect(g.winner!.id, 1);
    });

    test("paluba tugasa, tashlangan kartalar aralashtirilib qaytadi", () {
      final g = setup([
        [card(UnoColor.green, 1)],
      ], card(UnoColor.red, 5));
      final pile = [...g.drawPile];
      g.drawPile.clear();
      g.discardPile.insertAll(0, pile);
      final top = g.top;
      final got = g.give(g.players[1], 3);
      expect(got.length, 3);
      expect(g.top, top);
    });

    test("vaqt tugasa: 1 karta oladi, navbat o'tadi; o'yinchi chiqsa navbat to'g'ri qoladi", () {
      final g = setup([
        [card(UnoColor.green, 1)],
      ], card(UnoColor.red, 5), players: 3);
      g.timeout();
      expect(g.players[0].hand.length, 2);
      expect(g.players[0].timeouts, 1);
      expect(g.current.id, 2);
      g.leave(2);
      expect(g.current.id, 3);
      g.leave(3);
      expect(g.status, UnoStatus.finished);
    });

    test("tasodifiy to'liq o'yinlar oxiriga yetadi, kartalar yo'qolmaydi", () {
      for (var seed = 0; seed < 30; seed++) {
        final r = Random(seed);
        final g = UnoGame(ownerId: 1, random: r);
        final n = 2 + seed % 5;
        for (var k = 1; k <= n; k++) {
          g.join(k, 'P$k');
        }
        g.start();
        var moves = 0;
        while (g.status == UnoStatus.playing && moves < 3000) {
          final p = g.current;
          if (p.hand.length == 2 && r.nextBool()) g.sayUno(p.id);
          final can = g.playable(p);
          if (can.isNotEmpty) {
            final c = can[r.nextInt(can.length)];
            g.play(p.id, c.id, color: c.isWild ? UnoColor.values[r.nextInt(4)] : null);
          } else if (g.drawnThisTurn == null) {
            final got = g.draw(p.id);
            if (got == null || !g.canPlay(got)) {
              if (g.drawnThisTurn != null) g.pass(p.id);
            }
          } else {
            g.pass(p.id);
          }
          moves++;
          final total = g.drawPile.length + g.discardPile.length + g.players.fold(0, (s, p) => s + p.hand.length);
          expect(total, 108);
        }
        expect(g.status, UnoStatus.finished, reason: 'seed $seed');
      }
    });
  });
}
