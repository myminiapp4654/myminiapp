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

  test("yo'lak bo'ylab chizish chiqishga yetkazadi", () {
    final p = PlayerPath(small);
    expect(p.begin(1.5, 0.5), isTrue);
    for (final (x, y) in [(1.5, 1.5), (5.5, 1.5), (5.5, 3.5), (1.5, 3.5), (1.5, 5.5), (5.5, 5.5), (5.5, 6.5)]) {
      expect(p.move(x, y), isTrue);
    }
    expect(p.finished, isTrue);
    expect(p.cells, small.shortestPath());
  });

  test("devorga tegsa chizish uziladi, yo'l saqlanadi", () {
    final p = PlayerPath(small)..begin(1.5, 0.5);
    p.move(1.5, 1.5);
    p.move(3.5, 1.5);
    expect(p.move(3.5, 2.5), isFalse); // pastda devor
    expect(p.drawing, isFalse);
    final len = p.cells.length;
    // Uzilgandan keyin barmoq siljisa ham hech narsa bo'lmaydi
    p.move(4.5, 1.5);
    expect(p.cells.length, len);
    // Chiziq uchidan davom etish mumkin
    expect(p.begin(3.5, 1.5), isTrue);
    expect(p.move(5.5, 1.5), isTrue);
    expect(p.end, 1 * 7 + 5);
  });

  test("tez surilganda ham devordan sakrab o'tib bo'lmaydi", () {
    final p = PlayerPath(small)..begin(1.5, 0.5);
    p.move(1.5, 1.5);
    // 1-qatordan to'g'ri 3-qatorga (orada devor)
    expect(p.move(1.5, 3.5), isFalse);
    expect(p.cells.every((c) => !small.wall[c]), isTrue);
  });

  test("orqaga qaytsa chiziq o'chadi; chiziqdan uzoqda boshlab bo'lmaydi", () {
    final p = PlayerPath(small)..begin(1.5, 0.5);
    p.move(1.5, 1.5);
    p.move(5.5, 1.5);
    expect(p.cells.length, 6);
    p.move(2.5, 1.5);
    expect(p.cells.length, 3);
    p.stop();
    expect(p.begin(1.5, 5.5), isFalse);
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
    final rect = t.getRect(find.byKey(const ValueKey('maze')));
    final cell = rect.width / small.size;
    Offset at(int i) => rect.topLeft + Offset((small.col(i) + 0.5) * cell, (small.row(i) + 0.5) * cell);
    final path = small.shortestPath();
    final g = await t.startGesture(at(path.first));
    for (final i in path.skip(1)) {
      await g.moveTo(at(i));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Siz yutdingiz!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
