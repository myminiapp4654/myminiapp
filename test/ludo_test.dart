import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/ludo/ludo_screen.dart';
import 'package:oyinim/games/ludo/ludo_game.dart';

LudoGame game({int players = 2, Set<int> ai = const {}}) =>
    LudoGame(colors: LudoGame.colorsFor(players), ai: ai, random: Random(1));

void main() {
  group('Taxta', () {
    test("yo'l 52 ta turli katak, har biri keyingisiga yondosh", () {
      expect(kLudoPath.length, 52);
      expect(kLudoPath.toSet().length, 52);
      var diagonal = 0;
      for (var i = 0; i < 52; i++) {
        final a = kLudoPath[i], b = kLudoPath[(i + 1) % 52];
        final dr = (a.$1 - b.$1).abs(), dc = (a.$2 - b.$2).abs();
        expect(dr <= 1 && dc <= 1 && dr + dc > 0, isTrue, reason: '$i: $a -> $b');
        if (dr + dc == 2) diagonal++;
      }
      // Markaz atrofidagi 4 ta burchakda yo'l diagonal buriladi
      expect(diagonal, 4);
    });

    test("rangli yo'lak umumiy yo'lning oxirgi katagiga ulanadi", () {
      for (var c = 0; c < 4; c++) {
        final last = kLudoPath[LudoGame.globalOf(c, 50)];
        final first = kLudoHomeLane[c].first;
        expect((last.$1 - first.$1).abs() + (last.$2 - first.$2).abs(), 1,
            reason: 'rang $c');
      }
    });
  });

  test("uychadan faqat 6 bilan chiqiladi", () {
    final g = game();
    g.roll(3);
    expect(g.legalTokens(), isEmpty);
    expect(g.current, 2); // yurish yo'q — navbat sariqqa
    g.roll(6);
    expect(g.legalTokens(), [0, 1, 2, 3]);
    g.move(0);
    expect(g.tokens[2][0], 0);
    expect(g.current, 2); // 6 — yana tashlaydi
    expect(g.phase, LudoPhase.roll);
  });

  test("ketma-ket uchinchi 6 — navbat yonadi", () {
    final g = game();
    g.roll(6);
    g.move(0);
    g.roll(6);
    g.move(0);
    g.roll(6);
    expect(g.current, 2);
  });

  test("raqibni urish: uychasiga qaytadi, bonus yurish", () {
    final g2 = game();
    g2.tokens[0][0] = 7; // umumiy 7
    g2.tokens[2][0] = 36; // umumiy 10 (xavfsiz emas)
    g2.roll(3);
    final m = g2.move(0)!;
    expect(m.captured, [(2, 0)]);
    expect(g2.tokens[2][0], -1);
    expect(g2.current, 0); // bonus
    expect(g2.phase, LudoPhase.roll);
  });

  test("xavfsiz katakda urib bo'lmaydi", () {
    final g = game();
    g.tokens[0][0] = 5; // umumiy 5
    g.tokens[2][0] = 34; // umumiy (26+34)%52 = 8 — yulduz
    g.roll(3);
    final m = g.move(0)!;
    expect(m.captured, isEmpty);
    expect(g.tokens[2][0], 34);
    expect(g.current, 2);
  });

  test("marraga aniq son bilan; marraga yetsa bonus", () {
    final g = game();
    g.tokens[0][0] = 53;
    g.tokens[0][1] = kLudoHome;
    g.tokens[0][2] = kLudoHome;
    g.tokens[0][3] = 20;
    g.roll(5); // 53+5 = 58 > 56 — bu dona yurolmaydi
    expect(g.legalTokens(), [3]);
    g.move(3);
    expect(g.current, 2);

    final h = game();
    h.tokens[0][0] = 53;
    h.roll(3);
    final m = h.move(0)!;
    expect(m.reachedHome, isTrue);
    expect(h.current, 0); // bonus
  });

  test("4 ta dona marrada — g'alaba", () {
    final g = game();
    g.tokens[0] = [kLudoHome, kLudoHome, kLudoHome, 54];
    g.roll(2);
    g.move(3);
    expect(g.winner, 0);
    expect(g.phase, LudoPhase.finished);
  });

  test("rangli yo'lakdagi donani urib bo'lmaydi", () {
    final g = game(players: 4);
    g.tokens[0][0] = 52; // qizil yo'lagida
    g.tokens[1][0] = 0;
    // yashil hech qachon qizil yo'lagiga kira olmaydi — urish faqat umumiy yo'lda
    expect(ludoCell(0, 0, 52), isNot(ludoCell(1, 0, 0)));
  });

  test("kompyuter: urish imkoni bo'lsa uradi", () {
    final g = game(ai: {0});
    g.tokens[0][0] = 2; // umumiy 2
    g.tokens[0][1] = 7; // umumiy 7
    g.tokens[2][0] = 36; // umumiy 10 — qizilning 2-donasi 3 bilan uradi
    g.roll(3);
    expect(g.aiChoose(), 1);
  });

  test("kompyuterlar o'yinni oxirigacha o'ynab tugata oladi", () {
    for (var seed = 0; seed < 10; seed++) {
      final g = LudoGame(
          colors: LudoGame.colorsFor(4), ai: {0, 1, 2, 3}, random: Random(seed));
      var steps = 0;
      while (g.phase != LudoPhase.finished && steps < 5000) {
        g.roll();
        if (g.phase == LudoPhase.move) g.move(g.aiChoose()!);
        steps++;
      }
      expect(g.winner, isNotNull, reason: 'seed $seed');
    }
  });

  testWidgets("ekran: tosh tashlash, kompyuter o'zi o'ynaydi", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(
        home: LudoScreen(players: 2, ai: {2})));
    expect(find.text("Qizil navbati — toshni tashlang"), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('dice')));
    // Tosh ~0.4 s aylanadi, keyin: 6 bo'lsa dona tanlanadi, aks holda "yurish yo'q"
    for (var k = 0; k < 6; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final picked = find.text('Qizil: donani tanlang').evaluate().isNotEmpty;
    final noMove = find.textContaining("yurish yo'q").evaluate().isNotEmpty;
    expect(picked || noMove, isTrue);
    if (noMove) {
      // Navbat kompyuterga o'tadi va u o'zi tosh tashlaydi
      for (var k = 0; k < 15; k++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Sariq'), findsWidgets);
    }
    for (var k = 0; k < 60; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
