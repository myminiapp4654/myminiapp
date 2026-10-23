import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets("X-O ekrani: bosib o'ynash va g'alaba", (t) async {
    await t.pumpWidget(const MaterialApp(home: XoScreen(size: 3)));
    expect(find.text('X navbati'), findsOneWidget);

    for (final i in [0, 3, 1, 4, 2]) {
      await t.tap(find.byKey(ValueKey('cell-$i')));
      await t.pump();
    }
    expect(find.text('X yutdi!'), findsOneWidget);
    expect(find.text('X  1 : 0  O'), findsOneWidget);

    await t.tap(find.text("Yana o'ynash"));
    await t.pump();
    expect(find.text('O navbati'), findsOneWidget);
  });
}
