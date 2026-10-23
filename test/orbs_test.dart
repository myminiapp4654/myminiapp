import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/orbs/orbs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyinim/games/orbs/orbs_game.dart';

/// Portlashlar tugab, sharlar tinchlanguncha.
void settle(OrbsGame g) {
  for (var k = 0; k < 60 * 20 && !g.settled; k++) {
    g.update(1 / 60);
  }
}

/// Eng katta guruhni tanlaydigan oddiy o'yinchi.
int bestTap(OrbsGame g) {
  var best = -1, size = 0;
  for (var i = 0; i < g.orbs.length; i++) {
    final o = g.orbs[i];
    if (!o.alive) continue;
    var s = o.isBomb ? 6 : g.cluster(i).length;
    if (g.goal.color != null && !o.isBomb && o.color != g.goal.color) s ~/= 3;
    if (s > size) {
      size = s;
      best = i;
    }
  }
  return best;
}

void main() {
  test("daraja: sharlar taxtada, tinch, ichma-ich kirmagan", () {
    final g = OrbsGame(1);
    expect(g.orbs.length, 42);
    for (final o in g.orbs) {
      expect(o.x, inInclusiveRange(OrbsGame.radius - 1e-6, OrbsGame.width - OrbsGame.radius + 1e-6));
      expect(o.y, lessThanOrEqualTo(OrbsGame.height - OrbsGame.radius + 1e-6));
    }
    for (var a = 0; a < g.orbs.length; a++) {
      for (var b = a + 1; b < g.orbs.length; b++) {
        final dx = g.orbs[a].x - g.orbs[b].x, dy = g.orbs[a].y - g.orbs[b].y;
        expect(dx * dx + dy * dy, greaterThan(0.9 * 0.9));
      }
    }
  });

  test("daraja bir xil seed bilan har safar bir xil", () {
    final a = OrbsGame(5), b = OrbsGame(5);
    expect(a.orbs.map((o) => o.color), b.orbs.map((o) => o.color));
    expect(a.goal.target, b.goal.target);
  });

  test("guruh: faqat tegib turgan bir xil rangdagilar", () {
    final g = OrbsGame(1);
    final i = g.orbs.indexWhere((o) => !o.isBomb);
    final c = g.cluster(i);
    for (final k in c.keys) {
      expect(g.orbs[k].color, g.orbs[i].color);
    }
  });

  test("bosish: yurish kamayadi, guruh portlaydi, vazifa hisoblanadi", () {
    final g = OrbsGame(1);
    final i = bestTap(g);
    final size = g.cluster(i).length;
    final o = g.orbs[i];
    expect(g.tap(o.x, o.y), isTrue);
    expect(g.moves, g.startMoves - 1);
    expect(g.tap(o.x, o.y), isFalse); // zanjir tugamaguncha yangi yurish yo'q
    settle(g);
    expect(g.progress, greaterThanOrEqualTo(size));
    expect(g.aliveCount, lessThanOrEqualTo(42 - size));
  });

  test("bo'sh joyni bosish yurish sarflamaydi", () {
    final g = OrbsGame(1);
    expect(g.tap(4.5, 0.2), isFalse);
    expect(g.moves, g.startMoves);
  });

  test("bomba zanjiri: atrofidagi boshqa rangdagi sharlarni ham olib ketadi", () {
    final g = OrbsGame(4);
    final bi = g.orbs.indexWhere((o) => o.isBomb);
    expect(bi, isNot(-1));
    final bombOrb = g.orbs[bi];
    final colorsNear = g.orbs
        .where((o) =>
            !o.isBomb &&
            (o.x - bombOrb.x).abs() < 1.1 &&
            (o.y - bombOrb.y).abs() < 1.1)
        .map((o) => o.color)
        .toSet();
    final before = g.aliveCount;
    g.tap(bombOrb.x, bombOrb.y);
    settle(g);
    expect(g.aliveCount, lessThan(before - 3));
    expect(colorsNear.length, greaterThanOrEqualTo(1));
  });

  test("sharlar tushib, taxtaning tagida to'planadi", () {
    final g = OrbsGame(1);
    for (var k = 0; k < 3; k++) {
      final i = bestTap(g);
      g.tap(g.orbs[i].x, g.orbs[i].y);
      settle(g);
    }
    final lowest = g.orbs.where((o) => o.alive).map((o) => o.y).reduce((a, b) => a > b ? a : b);
    expect(lowest, closeTo(OrbsGame.height - OrbsGame.radius, 0.05));
    expect(g.settled, isTrue);
  });

  test("yurish tugasa va vazifa bajarilmasa — yutqazish", () {
    final g = OrbsGame(2)..moves = 0;
    settle(g);
    expect(g.result, OrbsResult.lost);
  });

  test("1–8 darajalarni oddiy o'yinchi ham yecha oladi (balans)", () {
    for (var level = 1; level <= 8; level++) {
      final g = OrbsGame(level);
      while (g.result == OrbsResult.playing) {
        final i = bestTap(g);
        if (i < 0) break;
        g.tap(g.orbs[i].x, g.orbs[i].y);
        settle(g);
      }
      expect(g.result, OrbsResult.won, reason: '$level-daraja: '
          '${g.progress}/${g.goal.target}, yurish ${g.startMoves}');
      expect(g.stars, greaterThanOrEqualTo(1));
    }
  });

  testWidgets("ekran: daraja ochiladi, sharni bosish yurish sarflaydi", (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: OrbsScreen()));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Chain Burst: 1-daraja'), findsOneWidget);
    expect((t.widget(find.byKey(const ValueKey('moves'))) as Text).data, '8');

    // Arenaning pastki qismidagi sharni bosamiz
    final arena = t.getRect(find.byKey(const ValueKey('arena')));
    await t.tapAt(Offset(arena.center.dx, arena.bottom - arena.width / 18));
    await t.pump(const Duration(milliseconds: 16));
    expect((t.widget(find.byKey(const ValueKey('moves'))) as Text).data, '7');
    for (var k = 0; k < 60; k++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pumpWidget(const SizedBox());
  });
}
