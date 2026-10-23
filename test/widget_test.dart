import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/xo/xo_ai.dart';
import 'package:oyinim/games/xo/xo_game.dart';
import 'package:oyinim/games/xo/xo_screen.dart';

void main() {
  group('XoGame', () {
    test("3×3: g'alaba, hisob, keyin yurib bo'lmaydi", () {
      final g = XoGame(3);
      expect(g.turn, 'X');
      for (final i in [0, 3, 1, 4, 2]) {
        expect(g.play(i), isTrue);
      }
      expect(g.winner, 'X');
      expect(g.line, [0, 1, 2]);
      expect(g.score, {'X': 1, 'O': 0});
      expect(g.play(5), isFalse);
    });

    test("band katakka yurib bo'lmaydi", () {
      final g = XoGame(3)..play(4);
      expect(g.play(4), isFalse);
      expect(g.turn, 'O');
    });

    test('durang', () {
      final g = XoGame(3);
      // X O X / X O O / O X X
      for (final i in [0, 1, 2, 4, 3, 5, 7, 6, 8]) {
        g.play(i);
      }
      expect(g.winner, 'draw');
      expect(g.draws, 1);
    });

    test("ikkala diagonal va ustun", () {
      expect(XoGame.winningLine(['X', '', '', '', 'X', '', '', '', 'X'], 3, 3, 4),
          [0, 4, 8]);
      expect(XoGame.winningLine(['', '', 'O', '', 'O', '', 'O', '', ''], 3, 3, 2),
          [2, 4, 6]);
      expect(XoGame.winningLine(['', 'X', '', '', 'X', '', '', 'X', ''], 3, 3, 7),
          [1, 4, 7]);
    });

    test("10×10: 5 tasi yutadi, qator chetidan o'tib ketmaydi", () {
      final b = List.filled(100, '');
      for (final i in [7, 8, 9, 10, 11]) {
        b[i] = 'X';
      }
      expect(XoGame.winningLine(b, 10, 5, 9), isNull);
      final g = XoGame(10);
      for (var k = 0; k < 4; k++) {
        g.play(k);
        g.play(90 + k);
      }
      g.play(4);
      expect(g.winner, 'X');
      expect(g.line, [0, 1, 2, 3, 4]);
    });

    test('yangi raundda birinchi navbat almashadi, hisob saqlanadi', () {
      final g = XoGame(3);
      for (final i in [0, 3, 1, 4, 2]) {
        g.play(i);
      }
      g.newRound();
      expect(g.turn, 'O');
      expect(g.round, 2);
      expect(g.board.every((c) => c.isEmpty), isTrue);
      expect(g.score['X'], 1);
    });
  });

  group('X-O kompyuter', () {
    test("qiyin 3×3: tasodifiy o'yinchiga hech qachon yutqazmaydi", () {
      final r = Random(1);
      for (var n = 0; n < 200; n++) {
        final g = XoGame(3);
        if (n.isOdd) g.newRound(); // birinchi yuruvchi almashsin
        while (!g.finished) {
          final empty = [for (var i = 0; i < 9; i++) if (g.board[i].isEmpty) i];
          g.play(g.turn == 'O'
              ? xoAiMove(g, 'O', 3, r)
              : empty[r.nextInt(empty.length)]);
        }
        expect(g.winner, isNot('X'));
      }
    });

    test("qiyin 3×3: o'ziga qarshi doim durang", () {
      final g = XoGame(3);
      while (!g.finished) {
        g.play(xoAiMove(g, g.turn, 3, Random(2)));
      }
      expect(g.winner, 'draw');
    });

    test("10×10: to'rttalik qatorni yakunlaydi va raqibnikini to'sadi", () {
      final g = XoGame(10);
      for (final i in [22, 23, 24, 25]) {
        g.board[i] = 'O';
      }
      final win = xoAiMove(g, 'O', 3, Random(1));
      expect([21, 26], contains(win));

      final h = XoGame(10);
      for (final i in [44, 45, 46]) {
        h.board[i] = 'X';
      }
      h.board[0] = 'O';
      expect([43, 47], contains(xoAiMove(h, 'O', 3, Random(1))));
    });

    test("10×10: qiyin kompyuter tasodifiy o'yinchini yutadi", () {
      final r = Random(3);
      for (var n = 0; n < 10; n++) {
        final g = XoGame(10);
        while (!g.finished) {
          final empty = [for (var i = 0; i < 100; i++) if (g.board[i].isEmpty) i];
          g.play(g.turn == 'O' ? xoAiMove(g, 'O', 3, r) : empty[r.nextInt(empty.length)]);
        }
        expect(g.winner, 'O');
      }
    });
  });

  testWidgets("X-O ekrani: siz va kompyuter navbatma-navbat", (t) async {
    await t.pumpWidget(const MaterialApp(home: XoScreen(size: 3, level: 3, seed: 1)));
    expect(find.text('Sizning navbatingiz'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('cell-4')));
    await t.pump();
    expect(find.text("Kompyuter o'ylayapti…"), findsOneWidget);
    // Kompyuter navbatida bosish hech narsa qilmaydi
    await t.tap(find.byKey(const ValueKey('cell-0')));
    await t.pump(const Duration(milliseconds: 800));
    expect(find.text('Sizning navbatingiz'), findsOneWidget);

    // Qolgan o'yinni oxirigacha o'ynaymiz
    for (var k = 0; k < 8 && find.text('Sizning navbatingiz').evaluate().isNotEmpty; k++) {
      for (var i = 0; i < 9; i++) {
        final cell = find.byKey(ValueKey('cell-$i'));
        final gd = t.widget<GestureDetector>(cell);
        if (gd.onTap != null) {
          await t.tap(cell);
          break;
        }
      }
      await t.pump(const Duration(milliseconds: 800));
    }
    expect(find.text('Siz yutdingiz!'), findsNothing); // qiyin 3×3 yutqazmaydi
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
