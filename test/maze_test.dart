import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/maze/maze_game.dart';
import 'package:oyinim/games/maze/maze_screen.dart';

/// Kichik qo'lda labirint: S tepada, E pastda.
final small = Maze.parse(const [
  '#S#####',
  '#.....#',
  '#####.#',
  '#.....#',
  '#.#####',
  '#.....#',
  '#####E#',
]);

void main() {
  test("labirint: o'lchamlar, kirish tepada, chiqish pastda, hamma yo'lak bog'langan", () {
    for (final level in [1, 2, 3]) {
      for (var seed = 0; seed < 10; seed++) {
        final m = Maze.generate(Maze.roomsFor(level), Random(seed));
        expect(m.size, {1: 25, 2: 29, 3: 33}[level]);
        expect(m.row(m.start), 0);
        expect(m.row(m.exit), m.size - 1);
        // Hamma yo'lak kirishdan yetib boriladi
        final seen = {m.start};
        final queue = [m.start];
        for (var k = 0; k < queue.length; k++) {
          for (final n in m.neighbors(queue[k])) {
            if (seen.add(n)) queue.add(n);
          }
        }
        final open = [for (var i = 0; i < m.size * m.size; i++) if (!m.wall[i]) i];
        expect(seen.length, open.length);
        expect(m.shortestPath().first, m.start);
        expect(m.shortestPath().last, m.exit);
      }
    }
  });

  int at(Maze m, int r, int c) => r * m.size + c;

  test("surilgan tomonga devorgacha yuradi, yopiq tomonga yurmaydi", () {
    final w = MazeWalker(small);
    expect(w.slide(-1, 0), isEmpty); // tepada labirint tashqarisi
    expect(w.slide(0, -1), isEmpty);
    expect(w.go(1, 0), [at(small, 1, 1)]); // pastda burilish — to'xtadi
    expect(w.go(0, 1), [for (var c = 2; c <= 5; c++) at(small, 1, c)]); // devorgacha
    expect(w.canGo(0, 1), isFalse);
  });

  test("yo'l o'rtasida yon burilish chiqsa — o'sha joyda to'xtaydi", () {
    final m = Maze.parse(const [
      '#S###',
      '#...#',
      '#.#.#',
      '#...#',
      '###E#',
    ]);
    final w = MazeWalker(m);
    expect(w.go(1, 0), [at(m, 1, 1)]); // o'ngga yo'l bor — pastga davom etmadi
    expect(w.go(1, 0), [at(m, 2, 1), at(m, 3, 1)]);
  });

  test("sirpanib chiqishga yetadi; orqaga qaytsa iz o'chadi", () {
    final w = MazeWalker(small);
    for (final (dr, dc) in const [(1, 0), (0, 1), (1, 0), (0, -1), (1, 0), (0, 1), (1, 0)]) {
      expect(w.go(dr, dc), isNotEmpty);
    }
    expect(w.finished, isTrue);
    expect(w.cells, small.shortestPath());

    final b = MazeWalker(small)..go(1, 0)..go(0, 1);
    expect(b.cells.length, 6);
    b.go(0, -1);
    expect(b.at, at(small, 1, 1));
    expect(b.cells.length, 2);
  });

  test("katta labirintlarda ham surib chiqish mumkin", () {
    for (var seed = 0; seed < 10; seed++) {
      final m = Maze.generate(Maze.roomsFor(3), Random(seed));
      final path = m.shortestPath();
      final w = MazeWalker(m);
      var guard = 0;
      while (!w.finished && guard++ < 2000) {
        // Eng qisqa yo'ldagi keyingi katak tomonga suramiz
        final k = path.indexOf(w.at);
        final next = path[k + 1];
        final dr = m.row(next) - m.row(w.at), dc = m.col(next) - m.col(w.at);
        final moved = w.slide(dr, dc);
        expect(moved, isNotEmpty);
        // Sirpanish eng qisqa yo'ldan chiqmaydi (burilishda to'xtaydi)
        for (final c in moved) {
          expect(path, contains(c));
        }
        moved.forEach(w.step);
      }
      expect(w.finished, isTrue);
    }
  });

  test("kompyuter doim chiqishni topadi; qiyini tezroq", () {
    double avg(int level) {
      var total = 0;
      for (var seed = 0; seed < 12; seed++) {
        final m = Maze.generate(14, Random(seed));
        final ai = MazeRunner(m, level, Random(seed));
        var steps = 0;
        while (!ai.finished) {
          ai.step();
          steps++;
          expect(steps, lessThan(m.size * m.size * 2));
        }
        expect(ai.stack.first, m.start);
        total += steps;
      }
      return total / 12 / MazeRunner(Maze.generate(14, Random(0)), level, Random(0)).speed;
    }

    // Soniyalarda: qiyin kompyuter tezroq chiqadi
    expect(avg(3), lessThan(avg(1)));
  });

  testWidgets("ekran: boshlash, sanoq, yo'lni chizib yutish", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: MazeScreen(initialMaze: small, seed: 1, level: 1)));
    await t.tap(find.byKey(const ValueKey('start')));
    for (var k = 0; k < 30; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final center = t.getCenter(find.byKey(const ValueKey('maze')));
    for (final (dr, dc) in const [(1, 0), (0, 1), (1, 0), (0, -1), (1, 0), (0, 1), (1, 0)]) {
      await t.dragFrom(center, Offset(dc * 60.0, dr * 60.0));
      for (var k = 0; k < 8; k++) {
        await t.pump(const Duration(milliseconds: 60));
      }
    }
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Siz yutdingiz!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
