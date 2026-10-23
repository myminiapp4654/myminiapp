import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/battleship/battleship_screen.dart';
import 'package:oyinim/games/battleship/battleship_game.dart';

int sq(String name) =>
    'abcdefghi'.indexOf(name[0]) + (int.parse(name.substring(1)) - 1) * 9;

/// Ikkala o'yinchi bir xil, oldindan ma'lum joylashuv bilan.
BattleshipGame readyGame() {
  final g = BattleshipGame();
  for (var p = 0; p < 2; p++) {
    final f = g.fleets[p];
    f.place(sq('a1'), 4, true); // a1-d1
    f.place(sq('a3'), 3, true); // a3-c3
    f.place(sq('e3'), 3, true); // e3-g3
    f.place(sq('a5'), 2, true);
    f.place(sq('d5'), 2, true);
    f.place(sq('g5'), 2, true);
    f.place(sq('a7'), 1, true);
    f.place(sq('c7'), 1, true);
    f.place(sq('e7'), 1, true);
    f.place(sq('g7'), 1, true);
    expect(f.complete, isTrue, reason: '$p-o\'yinchi kemalari');
    g.finishPlacing();
  }
  return g;
}

void main() {
  test('katak nomlari', () {
    expect(cellName(0), 'a1');
    expect(cellName(sq('f5')), 'f5');
    expect(cellName(80), 'i9');
  });

  group('Joylashtirish', () {
    test("taxtadan chiqib ketmaydi, gorizontal va vertikal", () {
      final f = Fleet();
      expect(f.canPlace(sq('g1'), 4, true), isFalse); // g,h,i — 3 ta joy
      expect(f.canPlace(sq('f1'), 4, true), isTrue);
      expect(f.canPlace(sq('a7'), 4, false), isFalse);
      expect(f.place(sq('a6'), 4, false), isTrue);
      expect(f.ships.single.cells, [sq('a6'), sq('a7'), sq('a8'), sq('a9')]);
    });

    test("kemalar ustma-ust ham, yonma-yon ham, burchakdan ham tegmaydi", () {
      final f = Fleet()..place(sq('c3'), 2, true); // c3,d3
      expect(f.canPlace(sq('c3'), 1, true), isFalse); // ustiga
      expect(f.canPlace(sq('e3'), 1, true), isFalse); // yonma-yon
      expect(f.canPlace(sq('e4'), 1, true), isFalse); // burchakdan
      expect(f.canPlace(sq('f3'), 1, true), isTrue); // bitta katak oraliq
    });

    test('har turdagi kemadan faqat kerakli soni', () {
      final f = Fleet()..place(sq('a1'), 4, true);
      expect(f.canPlace(sq('a3'), 4, true), isFalse);
      expect(f.remaining, [3, 3, 2, 2, 2, 1, 1, 1, 1]);
    });

    test("kemani olib tashlab qayta qo'yish", () {
      final f = Fleet()..place(sq('a1'), 4, true);
      expect(f.removeAt(sq('c1')), isTrue);
      expect(f.ships, isEmpty);
      expect(f.remaining.first, 4);
    });

    test("tasodifiy joylashtirish qoidalarga mos", () {
      for (var seed = 0; seed < 30; seed++) {
        final f = Fleet()..randomize(Random(seed));
        expect(f.complete, isTrue);
        final cells = f.ships.expand((s) => s.cells).toList();
        expect(cells.length, 20);
        // Har bir kema boshqasiga tegmaydi
        for (final s in f.ships) {
          for (final c in s.cells) {
            for (final n in Fleet.around(c)) {
              final other = f.shipAt(n);
              expect(other == null || other == s, isTrue);
            }
          }
        }
      }
    });

    test("ikkalasi tayyor bo'lgach jang boshlanadi", () {
      final g = BattleshipGame();
      g.fleets[0].randomize();
      expect(g.finishPlacing(), isTrue);
      expect(g.current, 1);
      expect(g.phase, Phase.placing);
      expect(g.finishPlacing(), isFalse); // 2-o'yinchi hali joylamagan
      g.fleets[1].randomize();
      g.finishPlacing();
      expect(g.phase, Phase.battle);
      expect(g.current, 0);
    });
  });

  group('Jang', () {
    test("tegmadi — navbat almashadi", () {
      final g = readyGame();
      expect(g.fire(sq('i9')), ShotResult.miss);
      expect(g.current, 1);
    });

    test("tegdi — yana otadi; hamma katagi tegsa portladi", () {
      final g = readyGame();
      expect(g.fire(sq('a1')), ShotResult.hit);
      expect(g.current, 0);
      g.fire(sq('b1'));
      g.fire(sq('c1'));
      expect(g.fire(sq('d1')), ShotResult.sunk);
      expect(g.shipsAlive(1), 9);
    });

    test("portlagan kema atrofi avtomatik belgilanadi, u yerga otib bo'lmaydi", () {
      final g = readyGame();
      expect(g.fire(sq('a7')), ShotResult.sunk);
      expect(g.autoMarked[0], containsAll([sq('b6'), sq('b7'), sq('b8'), sq('a8')]));
      expect(g.fire(sq('b7')), ShotResult.repeat);
      expect(g.current, 0);
    });

    test("bir katakka ikki marta otib bo'lmaydi", () {
      final g = readyGame();
      g.fire(sq('a1'));
      expect(g.fire(sq('a1')), ShotResult.repeat);
    });

    test("hamma kemasi portlasa — g'alaba, keyin yangi raund", () {
      final g = readyGame();
      for (final s in g.fleets[1].ships) {
        for (final c in s.cells) {
          g.fire(c);
        }
      }
      expect(g.phase, Phase.finished);
      expect(g.winner, 0);
      expect(g.score, [1, 0]);

      g.newRound();
      expect(g.phase, Phase.placing);
      expect(g.current, 1); // endi 2-o'yinchi boshlaydi
      expect(g.fleets[0].ships, isEmpty);
      expect(g.shots[0], isEmpty);
      expect(g.score, [1, 0]);
    });
  });

  testWidgets("ekran: joylashtirish -> uzatish -> jang", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: BattleshipScreen()));

    // 1-o'yinchi
    expect(find.text("Telefonni 1-o'yinchiga bering"), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump();
    await t.tap(find.text('Tasodifiy'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('ready')));
    await t.pump();

    // 2-o'yinchi
    expect(find.text("Telefonni 2-o'yinchiga bering"), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump();
    await t.tap(find.text('Tasodifiy'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('ready')));
    await t.pump();

    // Jang: 1-o'yinchi otadi
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump();
    expect(find.text("1-o'yinchi otadi"), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('target-0')));
    await t.pump();
    expect(find.textContaining('a1 — '), findsOneWidget);
  });
}
