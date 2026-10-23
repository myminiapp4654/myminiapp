import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/snake/snake_game.dart';
import 'package:oyinim/games/snake/snake_screen.dart';

/// Faqat o'yinchi qolgan, ozuqasiz dunyo.
SnakeWorld alone() {
  final w = SnakeWorld(level: 1, seed: 1);
  w.snakes.removeWhere((s) => !s.isPlayer);
  w.food.clear();
  return w;
}

void main() {
  test("boshlanish: o'yinchi markazda, kompyuterlar va ozuqa bor", () {
    final w = SnakeWorld(level: 2, seed: 1);
    expect(w.player.isPlayer, isTrue);
    expect(w.player.length, SnakeWorld.startLength);
    expect(w.snakes.where((s) => !s.isPlayer).length, w.botCount);
    expect(w.food.length, SnakeWorld.foodTarget);
  });

  test("ilon tinimsiz yuradi va yo'nalishi silliq buriladi", () {
    final w = alone();
    final start = w.player.head;
    w.steer(0); // o'ngga (boshida tepaga qarab turibdi)
    w.update(0.1);
    final a1 = w.player.angle;
    // Yoy bo'ylab yurgani uchun to'g'ri chiziqdan biroz qisqa
    expect((w.player.head - start).distance, closeTo(SnakeWorld.speed * 0.1, 2.5));
    expect(a1, greaterThan(-pi / 2)); // burila boshladi
    expect(a1, lessThan(0)); // lekin birdan emas
    for (var k = 0; k < 30; k++) {
      w.update(0.05);
    }
    expect(w.player.angle, closeTo(0, 0.01));
    // Bo'g'imlar orasidagi masofa saqlanadi
    final s = w.player.segs;
    for (var k = 1; k < s.length; k++) {
      expect((s[k] - s[k - 1]).distance, lessThanOrEqualTo(SnakeWorld.spacing + 0.001));
    }
  });

  test("keskin buriladi, lekin 150° dan ortiq emas (o'z ustiga qayrilmaydi)", () {
    final w = alone();
    final p = w.player;
    final start = p.angle; // tepaga
    w.steer(start + pi); // to'g'ri ortga
    expect((p.targetAngle - start).abs(), closeTo(150 * pi / 180, 1e-9));
    for (var k = 0; k < 15; k++) {
      w.update(1 / 60);
    }
    // 0.25 soniyada 150° ga burilib bo'ldi
    expect((p.angle - start).abs(), closeTo(150 * pi / 180, 1e-6));
    // 140° so'ralsa — to'liq 140°
    w.steer(p.angle + 140 * pi / 180);
    expect(p.targetAngle - p.angle, closeTo(140 * pi / 180, 1e-9));
  });

  test('ozuqa yeganda ilon uzayadi', () {
    final w = alone();
    final p = w.player;
    for (var k = 1; k <= 10; k++) {
      w.food.add(Food(p.head + Offset(0, -k * 12.0), 1, 1, 0));
    }
    final before = p.length;
    for (var k = 0; k < 60; k++) {
      w.update(1 / 60);
    }
    expect(w.food.where((f) => !f.fromDeath && f.pos.dx == 0 && f.pos.dy < 0 && f.pos.dy > -130), isEmpty);
    expect(p.length, greaterThan(before + 4));
  });

  test("boshqa ilon tanasiga urilgan ilon o'ladi va ozuqaga aylanadi", () {
    final w = alone();
    final p = w.player;
    // O'yinchi yo'liga ko'ndalang yotgan kompyuter ilon
    final bot = Snake(99, 'Devor', 2, start: p.head + const Offset(-120, -60), angle: pi, length: 30);
    w.snakes.add(bot);
    for (var k = 0; k < 60 && p.alive; k++) {
      w.update(1 / 60);
    }
    expect(p.alive, isFalse);
    expect(bot.kills, 1);
    expect(w.bursts, isNotEmpty);
    expect(w.food.where((f) => f.fromDeath && f.color == p.color).length, (p.length + 1) ~/ 2);
  });

  test("arena chetiga urilgan ilon o'ladi", () {
    final w = alone();
    final p = w.player;
    for (var k = 0; k < p.segs.length; k++) {
      p.segs[k] = Offset(0, -SnakeWorld.radius + 40 + k * SnakeWorld.spacing);
    }
    for (var k = 0; k < 60 && p.alive; k++) {
      w.update(1 / 60);
    }
    expect(p.alive, isFalse);
  });

  test("reyting uzunlik bo'yicha, o'lgan kompyuterlar o'rniga yangisi keladi", () {
    final w = SnakeWorld(level: 3, seed: 4);
    final lb = w.leaderboard;
    for (var k = 1; k < lb.length; k++) {
      expect(lb[k - 1].length, greaterThanOrEqualTo(lb[k].length));
    }
    final bot = w.snakes.firstWhere((s) => !s.isPlayer);
    w.kill(bot);
    for (var k = 0; k < 200; k++) {
      w.update(1 / 60);
    }
    expect(w.snakes.where((s) => !s.isPlayer && s.alive).length, w.botCount);
  });

  test("kompyuter ilonlar ko'pincha omon qoladi va kadr tez hisoblanadi", () {
    for (final level in [1, 3]) {
      final w = SnakeWorld(level: level, seed: 7);
      w.kill(w.player); // o'yinchi xalaqit bermasin
      var deaths = 0;
      final seen = <int>{};
      final sw = Stopwatch()..start();
      for (var k = 0; k < 60 * 30; k++) {
        final alive = {for (final s in w.snakes) if (s.alive && !s.isPlayer) s.id};
        w.update(1 / 60);
        for (final id in alive) {
          if (!w.snakes.any((s) => s.id == id && s.alive)) deaths++;
        }
        seen.addAll(alive);
      }
      final perFrame = sw.elapsedMicroseconds / (60 * 30);
      // 30 soniyada har bir kompyuter o'rtacha bir martadan kam o'ladi
      expect(deaths, lessThan(w.botCount * 2), reason: 'level $level: $deaths');
      expect(perFrame, lessThan(4000), reason: '$perFrame mks/kadr');
    }
  });

  testWidgets("ekran: barmoq bilan boshqarish, uzunlik ko'rinadi", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: SnakeScreen(seed: 1, level: 1)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Uzunlik:'), findsOneWidget);
    expect(find.textContaining('Reyting'), findsOneWidget);
    final c = t.getCenter(find.byKey(const ValueKey('arena')));
    final g = await t.startGesture(c);
    await g.moveBy(const Offset(40, 0));
    for (var k = 0; k < 20; k++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    await t.pumpWidget(const SizedBox());
  });
}
