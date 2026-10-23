import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/snakes/snakes_game.dart';
import 'package:oyinim/games/snakes/snakes_screen.dart';

SnakesGame fixed({int players = 2}) => SnakesGame(
      ladders: {4: 14, 9: 31},
      snakes: {17: 7, 99: 78},
      looks: {17: const SnakeLook(0, 2, 0.2, 0, 0), 99: const SnakeLook(0.5, 3, 0.2, 1, 1)},
      players: players,
    );

void main() {
  test("kataklar ilon izi bo'ylab: 1 pastki chapda, 11 — 2-qatorda o'ngda", () {
    expect(SnakesGame.cellRC(1), (0, 0));
    expect(SnakesGame.cellRC(10), (0, 9));
    expect(SnakesGame.cellRC(11), (1, 9));
    expect(SnakesGame.cellRC(20), (1, 0));
    expect(SnakesGame.cellRC(100), (9, 0));
  });

  test("tasodifiy taxta: 6 narvon, 6 ilon, uchlari takrorlanmaydi, har safar boshqa", () {
    final seen = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      final b = SnakesBoard.generate(Random(seed));
      expect(b.ladders.length, 6);
      expect(b.snakes.length, 6);
      final ends = [...b.ladders.keys, ...b.ladders.values, ...b.snakes.keys, ...b.snakes.values];
      expect(ends.toSet().length, ends.length);
      expect(ends, isNot(contains(1)));
      expect(ends, isNot(contains(100)));
      b.ladders.forEach((from, to) {
        expect(to ~/ 10 > (from - 1) ~/ 10 || (to - 1) ~/ 10 > (from - 1) ~/ 10, isTrue);
        expect(to, greaterThan(from));
      });
      b.snakes.forEach((head, tail) => expect(tail, lessThan(head)));
      expect(b.looks.keys.toSet(), b.snakes.keys.toSet());
      seen.add('${b.ladders}${b.snakes}');
    }
    expect(seen.length, 300);
  });

  test('narvon tepaga chiqaradi, ilon pastga tushiradi', () {
    final g = fixed();
    final m = g.roll(4); // 0 -> 4 -> narvon 14
    expect(m.steps, [1, 2, 3, 4]);
    expect(m.ladder, isTrue);
    expect(g.pos[0], 14);
    expect(g.current, 1);
    g.roll(6); // 2-o'yinchi 6 da
    final s = g.roll(3); // 14 -> 17 -> ilon 7
    expect(s.snake, isTrue);
    expect(g.pos[0], 7);
  });

  test("100 ga aniq yetish kerak: ortig'i orqaga qaytaradi", () {
    final g = fixed()..pos[0] = 97;
    final m = g.roll(5); // 98 99 100 99 98
    expect(m.steps, [98, 99, 100, 99, 98]);
    expect(g.pos[0], 98);
    expect(g.winner, isNull);
    g.roll(1);
    g.pos[0] = 96;
    g.roll(4);
    expect(g.winner, 0);
    expect(g.finished, isTrue);
  });

  test("o'yin doim tugaydi", () {
    for (var seed = 0; seed < 50; seed++) {
      final r = Random(seed);
      final g = SnakesGame.random(players: 4, random: r);
      var turns = 0;
      while (!g.finished && turns < 5000) {
        g.roll(1 + r.nextInt(6));
        turns++;
      }
      expect(g.finished, isTrue);
    }
  });

  testWidgets("ekran: zarni bosasiz, tosh yuradi, kompyuter navbati", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: SnakesScreen(initialGame: fixed(), seed: 3)));
    expect(find.text('Zarni bosing!'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('dice')));
    await t.pump(const Duration(milliseconds: 100));
    // Kompyuter navbatida zar bosilmaydi
    for (var k = 0; k < 60 && find.text("Ko'k o'ylayapti…").evaluate().isEmpty; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("Ko'k o'ylayapti…"), findsOneWidget);
    for (var k = 0; k < 80 && find.text('Zarni bosing!').evaluate().isEmpty; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Zarni bosing!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
