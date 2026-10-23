import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/orbs/orbs_game.dart';
import 'package:oyinim/games/orbs/orbs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hamma portlashlar tugaguncha.
void finish(OrbsGame g) {
  for (var k = 0; k < 60 * 60 && !g.finished; k++) {
    g.update(1 / 60);
  }
}

/// Sharlar joyida turgan (harakatsiz) o'yin.
OrbsGame still(List<(double, double)> points) {
  final g = OrbsGame(1, seed: 1);
  g.orbs
    ..clear()
    ..addAll([for (final (x, y) in points) Orb(x, y, 0, 0, 0)]);
  return g;
}

void main() {
  test('12 ta daraja: 1-darajada 5 tadan 1 ta, oxirgisida 60 tadan 55 ta', () {
    expect(OrbsGame.levelCount, 12);
    expect(OrbsGame(1, seed: 1).orbs.length, 5);
    expect(OrbsGame(1).info.target, 1);
    expect(OrbsGame(12).info.total, 60);
    expect(OrbsGame(12).info.target, 55);
  });

  test("har darajada faqat bir marta bosiladi", () {
    final g = OrbsGame(3, seed: 2);
    expect(g.tap(4, 7), isTrue);
    expect(g.tap(1, 1), isFalse);
    expect(g.blasts.length, 1);
  });

  test("halqaga tekkan shar portlaydi, uzoqdagisi yo'q", () {
    final g = still([(4.5, 7), (8, 13)]);
    g.tap(4.5, 7.3);
    finish(g);
    expect(g.caught, 1);
    expect(g.orbs[1].alive, isTrue);
  });

  test("zanjir: har keyingi bo'g'in ko'proq ochko beradi", () {
    // Sharlar bir qatorda: har biri faqat oldingisining halqasiga yetadi
    final g = still([(1, 7), (2.45, 7), (3.9, 7), (5.35, 7)]);
    g.tap(0.7, 7);
    finish(g);
    expect(g.caught, 4);
    expect(g.maxGeneration, 4);
    expect(g.score, 100 + 200 + 300 + 400);
    expect(g.catches.map((c) => c.generation), [1, 2, 3, 4]);
  });

  test("halqa kattalashadi, turadi va so'nadi", () {
    final g = still([(8, 13)]);
    g.tap(1, 1);
    final b = g.blasts.single;
    expect(b.scale, 0);
    for (var k = 0; k < 15; k++) {
      g.update(1 / 60); // 0.25 s
    }
    expect(b.scale, closeTo(1, 0.05));
    for (var k = 0; k < 30; k++) {
      g.update(1 / 60);
    }
    expect(b.scale, 1);
    finish(g);
    expect(g.blasts, isEmpty);
    expect(g.finished, isTrue);
  });

  test("natija: yetarli ushlansa yutish, aks holda yutqazish", () {
    final win = still([(4, 7)])..tap(4, 7);
    finish(win);
    expect(win.result, OrbsResult.won);

    final lose = still([(8, 13)])..tap(1, 1);
    finish(lose);
    expect(lose.result, OrbsResult.lost);
  });

  test("sharlar maydondan chiqib ketmaydi", () {
    final g = OrbsGame(12, seed: 5);
    for (var k = 0; k < 600; k++) {
      g.update(1 / 60);
    }
    for (final o in g.orbs) {
      expect(o.x, inInclusiveRange(0, OrbsGame.width));
      expect(o.y, inInclusiveRange(0, OrbsGame.height));
    }
  });

  test("balans: to'g'ri joyni tanlasa 1–10 darajalardan o'tish mumkin", () {
    for (var level = 1; level <= 10; level++) {
      var wins = 0;
      for (var seed = 0; seed < 6; seed++) {
        var best = 0;
        // 1 soniya kutib, maydonning turli joylarini sinab ko'ramiz
        for (var gx = 0; gx < 6 && best < OrbsGame.levels[level - 1].target; gx++) {
          for (var gy = 0; gy < 9; gy++) {
            final g = OrbsGame(level, seed: seed * 100 + level);
            g.update(1);
            g.tap(0.75 + gx * 1.5, 0.78 + gy * 1.55);
            finish(g);
            if (g.caught > best) best = g.caught;
          }
        }
        if (best >= OrbsGame.levels[level - 1].target) wins++;
      }
      expect(wins, greaterThanOrEqualTo(4), reason: '$level-daraja: 6 tadan $wins');
    }
  });

  testWidgets("ekran: bir bosish, zanjir, natija", (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: OrbsScreen()));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Chain Burst: 1-daraja'), findsOneWidget);
    expect(find.textContaining('0 / 1'), findsOneWidget);

    await t.tapAt(t.getCenter(find.byKey(const ValueKey('arena'))));
    for (var k = 0; k < 400; k++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    // Daraja tugadi: natija oynasi
    expect(
      find.text('Bajarildi!').evaluate().isNotEmpty ||
          find.text('Yana urinib ko\'ring').evaluate().isNotEmpty,
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
