import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/chain/chain_screen.dart';
import 'package:oyinim/games/chain/chain_ai.dart';
import 'package:oyinim/games/chain/chain_game.dart';

void main() {
  test("sig'im: burchak 2, chet 3, o'rta 4", () {
    final g = ChainGame(rows: 9, cols: 6);
    expect(g.capacity(0), 2);
    expect(g.capacity(5), 2);
    expect(g.capacity(53), 2);
    expect(g.capacity(2), 3);
    expect(g.capacity(6), 3);
    expect(g.capacity(7), 4);
  });

  test("raqib katagiga qo'yib bo'lmaydi, navbat almashadi", () {
    final g = ChainGame();
    expect(g.play(7), isTrue);
    expect(g.current, 1);
    expect(g.play(7), isFalse);
    expect(g.play(8), isTrue);
    expect(g.current, 0);
  });

  test('burchak 2 ta sharda portlaydi va qo\'shnilarni egallaydi', () {
    final g = ChainGame();
    g.play(0); // 0-o'yinchi
    g.play(20); // 1-o'yinchi uzoqda
    g.play(0); // 2-shar — portlaydi
    expect(g.count[0], 0);
    expect(g.owner[0], -1);
    expect(g.owner[1], 0);
    expect(g.owner[6], 0);
    expect(g.count[1], 1);
    expect(g.count[6], 1);
  });

  test("portlash raqib sharlarini o'z rangiga aylantiradi", () {
    final g = ChainGame();
    g.play(0); // 0
    g.play(1); // 1-o'yinchi 0 ning yonida
    g.play(0); // 0 portlaydi -> 1-katak 0-o'yinchiga o'tadi (2 ta shar)
    expect(g.owner[1], 0);
    expect(g.count[1], 2);
    // 1-o'yinchining shari qolmadi, hamma yurgan -> 0 yutdi
    expect(g.winner, 0);
    expect(g.score, [1, 0]);
  });

  test("zanjir to'lqinlari bosqichma-bosqich", () {
    final g = ChainGame();
    g.play(0); // 0
    g.play(30); // 1
    g.play(1); // 0: 1-katak (chet, sig'im 3) -> 1 shar
    g.play(31); // 1
    g.play(1); // 0: 1-katakda 2 ta
    g.play(32); // 1
    // 0-katakka 2-shar: burchak portlaydi -> 1-katakda 3 ta -> u ham portlaydi
    expect(g.place(0), isTrue);
    expect(g.step(), [0]);
    expect(g.count[1], 3);
    expect(g.step(), [1]);
    expect(g.step(), isNotNull);
    g.endTurn();
    expect(g.exploding, isFalse);
    expect(g.current, 1);
  });

  test("birinchi raund tugaguncha hech kim chiqib ketmaydi", () {
    final g = ChainGame(players: 3);
    g.play(0); // 0
    expect(g.winner, isNull);
    expect(g.isAlive(1), isTrue);
    expect(g.isAlive(2), isTrue);
  });

  test("sharsiz qolgan o'yinchi navbatdan o'tkazib yuboriladi", () {
    final g = ChainGame(players: 3);
    g.play(0); // 0
    g.play(1); // 1 — 0 ning yonida
    g.play(50); // 2 — uzoqda
    g.play(0); // 0 portlaydi, 1-o'yinchini yeydi
    expect(g.isAlive(1), isFalse);
    expect(g.winner, isNull); // 2-o'yinchi hali bor
    expect(g.current, 2); // 1 o'tkazib yuborildi
  });

  test("butun taxta to'lsa ham zanjir cheksiz aylanmaydi", () {
    final g = ChainGame(rows: 3, cols: 3);
    var moves = 0;
    while (!g.finished && moves < 500) {
      final i = List.generate(9, (k) => k).firstWhere(g.canPlace);
      g.play(i);
      moves++;
    }
    expect(g.finished, isTrue);
  });

  test('yurishni orqaga qaytarish', () {
    final g = ChainGame();
    g.play(7);
    expect(g.canUndo, isTrue);
    expect(g.undo(), isTrue);
    expect(g.count[7], 0);
    expect(g.current, 0);
    expect(g.canUndo, isFalse);
  });

  test("yangi raundda boshlovchi almashadi, hisob saqlanadi", () {
    final g = ChainGame();
    g.play(0);
    g.play(1);
    g.play(0);
    expect(g.winner, 0);
    g.newRound();
    expect(g.current, 1);
    expect(g.round, 2);
    expect(g.score, [1, 0]);
    expect(g.count.every((c) => c == 0), isTrue);
  });

  testWidgets("ekran: siz yurasiz, kompyuter javob beradi", (t) async {
    await t.pumpWidget(const MaterialApp(home: ChainScreen(seed: 1)));
    expect(find.text('Sizning navbatingiz'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cell-0')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text("Ko'k o'ylayapti…"), findsOneWidget);
    // Kompyuter navbatida bosish hech narsa qilmaydi
    await t.tap(find.byKey(const ValueKey('cell-5')));
    await t.pump(const Duration(milliseconds: 1200));
    expect(find.text('Sizning navbatingiz'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // titrash animatsiyasini to'xtatish
  });

  group('kompyuter', () {
    test("yutuvchi yurishni topadi", () {
      final h = ChainGame();
      h.play(0);
      h.play(1);
      // Qizil: 0 burchakda 1 ta, ko'k: 1 da 1 ta. 0 ga qo'yilsa portlab ko'k yo'qoladi
      expect(chainAiMove(h, 3, Random(1)), 0);
      h.play(0);
      expect(h.winner, 0);
    });

    test("darajalar: qiyin kompyuter osonini yutadi", () {
      var wins = 0;
      for (var n = 0; n < 4; n++) {
        final g = ChainGame();
        if (n.isOdd) g.newRound();
        final r = Random(n);
        for (var k = 0; k < 400 && !g.finished; k++) {
          expect(g.play(chainAiMove(g, g.current == 0 ? 3 : 1, r)), isTrue);
        }
        if (g.winner == 0) wins++;
      }
      expect(wins, greaterThanOrEqualTo(3));
    });
  });

  test("8 o'yinchi: navbat hammasidan aylanib chiqadi", () {
    final g = ChainGame(players: 8, rows: 12, cols: 8);
    for (var p = 0; p < 8; p++) {
      expect(g.current, p);
      g.play(p * 12 + 5); // har biri alohida katakka
    }
    expect(g.current, 0);
    expect(g.winner, isNull);
  });
}
