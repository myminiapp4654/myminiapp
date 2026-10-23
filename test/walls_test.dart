import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/walls/walls_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyinim/games/walls/walls_game.dart';

/// Hamma g'ishti bir xil turdagi devor.
WallsGame withBricks(BrickType type, {int wall = 1}) {
  final g = WallsGame(random: Random(1))..wall = wall;
  g.bricks = [
    for (var i = 0; i < WallsGame.rows * WallsGame.cols; i++) Brick(type, 3),
  ];
  return g;
}

/// Joriy devorni oxirigacha buzadi (yangi devorga o'tmaydi).
void breakAll(WallsGame g) {
  final wall = g.wall;
  for (var i = 0; i < g.bricks.length; i++) {
    while (!g.bricks[i].broken && g.stunned == 0) {
      g.tap(i);
      if (g.wall != wall || g.escaped) return;
    }
  }
}

void main() {
  test("1-devor: musht 1 zarba, oddiy g'isht 3 ta zarbada sinadi va pul beradi", () {
    final g = withBricks(BrickType.normal);
    expect(g.tapDamage, 1);
    expect(g.tap(0).broken, isFalse);
    g.tap(0);
    final r = g.tap(0);
    expect(r.broken, isTrue);
    expect(r.gained, greaterThan(0));
    expect(g.money, r.gained);
    expect(g.tap(0).damage, 0); // singan g'ishtga zarba yo'q
  });

  test("temirni musht bilan deyarli sindirib bo'lmaydi, bolg'a bilan bo'ladi", () {
    final g = withBricks(BrickType.metal);
    expect(g.tap(0).damage, closeTo(0.1, 1e-9));
    g.money = 1000;
    expect(g.buyTool(), isTrue);
    expect(WallsGame.tools[g.tool].name, "Bolg'a");
    expect(g.tap(1).damage, 4);
  });

  test("tok urilsa qo'l ishlamaydi, vaqt o'tsa tiklanadi; himoya bilan urmaydi", () {
    final g = withBricks(BrickType.shock);
    breakAll(g);
    expect(g.stunned, greaterThan(0));
    expect(g.tap(5).damage, 0);
    g.tick(3);
    expect(g.stunned, 0);
    expect(g.tap(5).damage, greaterThan(0));

    final safe = withBricks(BrickType.shock)..insulation = true;
    for (var k = 0; k < 3; k++) {
      safe.tap(0);
    }
    expect(safe.bricks[0].broken, isTrue);
    expect(safe.stunned, 0);
  });

  test("qulash buzilgan g'ishtlarni qayta tiklaydi", () {
    final g = withBricks(BrickType.normal);
    for (final i in [0, 1, 2]) {
      g.bricks[i].hp = 0;
    }
    g.bricks[3] = Brick(BrickType.collapse, 1);
    final r = g.tap(3);
    expect(r.trap, BrickType.collapse);
    expect([0, 1, 2].where((i) => !g.bricks[i].broken).length, 2);
  });

  test("devor to'liq buzilsa keyingi devor, oxirgisidan keyin — qochib chiqdingiz", () {
    final g = withBricks(BrickType.normal);
    breakAll(g);
    expect(g.wall, 2);
    expect(g.bricksLeft, WallsGame.rows * WallsGame.cols);

    final last = withBricks(BrickType.normal, wall: WallsGame.finalWall);
    breakAll(last);
    expect(last.escaped, isTrue);
    expect(last.tap(0).damage, 0);
  });

  test("qochgach qayta boshlash: hammasi nolga, daromad +25%", () {
    final g = withBricks(BrickType.normal, wall: WallsGame.finalWall)
      ..money = 999
      ..tool = 3;
    breakAll(g);
    g.restartAfterEscape();
    expect(g.escapes, 1);
    expect(g.wall, 1);
    expect(g.money, 0);
    expect(g.tool, 0);
    expect(g.incomeMultiplier, 1.25);
  });

  test("do'kon: pul yetmasa sotib olinmaydi, narx oshib boradi", () {
    final g = withBricks(BrickType.normal);
    expect(g.buyPower(), isFalse);
    g.money = 15;
    final cost = g.powerCost;
    expect(g.buyPower(), isTrue);
    expect(g.money, 0);
    expect(g.powerLvl, 1);
    expect(g.powerCost, greaterThan(cost));
    expect(g.tapDamage, 2);

    g.money = 10000;
    expect(g.buyScanner(), isTrue);
    expect(g.buyScanner(), isFalse); // bir martalik
    expect(g.isRevealed(0), isTrue);
  });

  test("ishchilar devorni o'zi buzadi", () {
    final g = withBricks(BrickType.normal)..workerLvl = 5; // 3 zarba/soniya
    final before = g.bricksLeft;
    g.tick(10);
    expect(g.bricksLeft, lessThan(before));
    expect(g.money, greaterThan(0));
  });

  test("dinamit 3×3 maydonni portlatadi, tuzoq ishlamaydi", () {
    final g = withBricks(BrickType.shock)..dynamite = 1;
    final i = 2 * WallsGame.cols + 2; // o'rtadagi katak
    final res = g.useDynamite(i);
    expect(res.length, 9);
    expect(g.stunned, 0);
    expect(g.dynamite, 0);
    expect(g.useDynamite(0), isEmpty);
  });

  test("kritik zarba 3 barobar", () {
    final g = withBricks(BrickType.normal)..critLvl = 10; // 50%
    g.bricks = [for (var i = 0; i < 48; i++) Brick(BrickType.normal, 1000)];
    final hits = [for (var k = 0; k < 200; k++) g.tap(k % 48)];
    expect(hits.any((h) => h.crit && h.damage == 3), isTrue);
    expect(hits.any((h) => !h.crit && h.damage == 1), isTrue);
  });

  test("saqlash va yuklash", () {
    final g = WallsGame(random: Random(3))
      ..money = 123.5
      ..wall = 7
      ..tool = 2
      ..scanner = true;
    g.tap(0);
    final copy = WallsGame.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(copy.money, closeTo(g.money, 1e-9));
    expect(copy.wall, 7);
    expect(copy.tool, 2);
    expect(copy.scanner, isTrue);
    expect(copy.bricks[0].hp, g.bricks[0].hp);
    expect(copy.bricks.map((b) => b.type), g.bricks.map((b) => b.type));
  });

  test("balans: 1-devorni musht bilan 1–3 daqiqada buzish mumkin", () {
    final g = WallsGame(random: Random(7));
    var taps = 0;
    while (g.wall == 1 && taps < 5000) {
      final i = g.bricks.indexWhere((b) => !b.broken);
      if (g.stunned > 0) {
        g.tick(0.5);
        continue;
      }
      g.tap(i);
      taps++;
    }
    // Sekundiga ~4 bosish — 1 devor 60–180 bosishda tugashi kerak
    expect(taps, inInclusiveRange(100, 400));
  });

  test('pul formati', () {
    expect(formatMoney(5.25), '5.3');
    expect(formatMoney(950), '950');
    expect(formatMoney(1250), '1.3K');
    expect(formatMoney(2500000), '2.5M');
  });

  testWidgets("ekran: g'ishtni urish, do'kon, saqlash", (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(const MaterialApp(home: WallsScreen()));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('1/25-devor'), findsOneWidget);

    // Birinchi g'ishtni singuncha uramiz
    for (var k = 0; k < 40; k++) {
      final brick = find.byKey(const ValueKey('brick-0'));
      if (brick.evaluate().isEmpty) break;
      await t.tap(brick);
      await t.pump(const Duration(milliseconds: 120));
    }
    expect(find.byKey(const ValueKey('brick-0')), findsNothing);
    expect(find.textContaining('💰 0.0'), findsNothing); // pul tushdi

    await t.tap(find.byKey(const ValueKey('shop')));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text("Do'kon"), findsOneWidget);

    // Ekrandan chiqqanda saqlanadi
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('walls_save_v1'), isNotNull);
  });
}
