import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/battleship/battleship_ai.dart';
import 'package:oyinim/games/battleship/battleship_placement.dart';
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

  group('Kompyuter otishi', () {
    /// Kompyuter (1) hamma kemani nechta o'qda cho'ktiradi.
    int shotsToWin(int level, int seed) {
      final r = Random(seed);
      final g = BattleshipGame();
      g.fleets[0].randomize(r);
      g.fleets[1].randomize(r);
      g.finishPlacing();
      g.finishPlacing();
      g.current = 1;
      var n = 0;
      while (g.phase == Phase.battle) {
        g.current = 1; // faqat kompyuter otadi
        final cell = battleshipAiShot(g, 1, level, r);
        expect(g.fire(cell), isNot(ShotResult.repeat));
        n++;
      }
      expect(g.winner, 1);
      return n;
    }

    test("har darajada hamma kemani topadi, takror otmaydi", () {
      for (final level in [1, 2, 3]) {
        for (var s = 0; s < 5; s++) {
          expect(shotsToWin(level, s), lessThanOrEqualTo(kCells));
        }
      }
    });

    test("qiyin kompyuter osonidan kamroq o'q sarflaydi", () {
      double avg(int level) =>
          [for (var s = 0; s < 20; s++) shotsToWin(level, s)].reduce((a, b) => a + b) / 20;
      final easy = avg(1), mid = avg(2), hard = avg(3);
      expect(hard, lessThan(easy - 4), reason: 'oson $easy, qiyin $hard');
      expect(hard, lessThan(mid));
      expect(mid, lessThan(easy));
    });

    test("tekkan kemani ta'qib qiladi", () {
      final g = readyGame();
      g.current = 1;
      expect(g.fire(sq('b1')), ShotResult.hit); // 4 katakli kema a1-d1
      g.current = 1;
      final next = battleshipAiShot(g, 1, 2, Random(1));
      expect([sq('a1'), sq('c1'), sq('b2')], contains(next));
    });
  });

  testWidgets("ekran: joylashtirish -> jang -> kompyuter javob otadi", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: BattleshipScreen(seed: 1)));

    // Kemalar
    await t.tap(find.text('Tasodifiy'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('ready')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('RAQIB DENGIZI'), findsOneWidget);

    // Tegmaguncha otamiz
    for (var k = 0; k < 81; k++) {
      final cell = find.byKey(ValueKey('target-$k'));
      await t.tap(cell, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 50));
      if (find.textContaining('Tegmadi').evaluate().isNotEmpty) break;
    }
    // Katta taxta joyida qoladi, kompyuter navbati boshlanadi
    await t.pump(const Duration(milliseconds: 1100));
    expect(find.text('RAQIB DENGIZI'), findsOneWidget);
    expect(find.text('Kompyuter otyapti…'), findsOneWidget);
    // ...va oxiri navbat qaytadi
    for (var k = 0; k < 60 && find.text('Kompyuter otyapti…').evaluate().isNotEmpty; k++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(find.textContaining('Sizning navbatingiz'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  group('Sudrab joylashtirish', () {
    late Fleet fleet;

    Future<void> pumpPlacement(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      fleet = Fleet();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BattleshipPlacement(fleet: fleet, title: 'Test', onReady: () {}),
        ),
      ));
    }

    /// Portdagi [k]-kemani chap katagidan ushlab, taxtadagi [cell] ga olib boradi.
    Future<void> dragPortShip(WidgetTester t, int k, int cell) async {
      final ship = t.getRect(find.byKey(ValueKey('port-$k')));
      final target = t.getCenter(find.byKey(ValueKey('place-$cell')));
      final grip = Offset(ship.left + 5, ship.center.dy);
      final g = await t.startGesture(grip);
      await g.moveBy(const Offset(0, -20));
      await t.pump();
      await g.moveTo(target);
      await t.pump();
      await g.up();
      await t.pump();
    }

    testWidgets("portdan sudrab qo'yiladi", (t) async {
      await pumpPlacement(t);
      expect(find.byKey(const ValueKey('port-0')), findsOneWidget);
      await dragPortShip(t, 0, sq('b2')); // 4 katakli kema b2 dan
      expect(fleet.ships.single.cells, [sq('b2'), sq('c2'), sq('d2'), sq('e2')]);
      expect(fleet.remaining.contains(4), isFalse);
    });

    testWidgets("taxtadagi kemani bosish — buriladi", (t) async {
      await pumpPlacement(t);
      await dragPortShip(t, 0, sq('b2'));
      await t.tap(find.byKey(ValueKey('place-${sq('c2')}')));
      await t.pump();
      expect(fleet.ships.single.cells, [sq('b2'), sq('b3'), sq('b4'), sq('b5')]);
    });

    testWidgets("qo'yib bo'lmaydigan joyga tashlansa — portda qoladi", (t) async {
      await pumpPlacement(t);
      await dragPortShip(t, 0, sq('g2')); // g,h,i — sig'maydi
      expect(fleet.ships, isEmpty);
    });

    testWidgets("taxtadan tashqariga tashlansa — portga qaytadi", (t) async {
      await pumpPlacement(t);
      await dragPortShip(t, 0, sq('b2'));
      final g = await t.startGesture(t.getCenter(find.byKey(ValueKey('place-${sq('c2')}'))));
      await g.moveBy(const Offset(0, -20));
      await t.pump();
      await g.moveTo(const Offset(10, 10)); // ekran burchagi — taxtadan tashqarida
      await t.pump();
      await g.up();
      await t.pump();
      expect(fleet.ships, isEmpty);
    });
  
    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      testWidgets("${size.width.toInt()}×${size.height.toInt()} ekranga sig'adi", (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Dengiz jangi')),
            body: SafeArea(
              child: BattleshipPlacement(
                  fleet: Fleet(), title: "1-o'yinchi", onReady: () {}),
            ),
          ),
        ));
        expect(t.takeException(), isNull);
      });
    }
  });
}
