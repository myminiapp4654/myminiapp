import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/chess/chess_screen.dart';
import 'package:oyinim/games/chess/chess_game.dart';

void main() {
  group('Perft (yurish generatorining rasmiy raqamlari)', () {
    test("boshlang'ich pozitsiya: 20 / 400 / 8902", () {
      final g = ChessGame();
      expect(g.perft(1), 20);
      expect(g.perft(2), 400);
      expect(g.perft(3), 8902);
    });

    test('Kiwipete (rokirovka, en passant, aylanish): 48 / 2039', () {
      final g = ChessGame(
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
      expect(g.perft(1), 48);
      expect(g.perft(2), 2039);
    });

    test('3-pozitsiya (en passant va shax): 14 / 191 / 2812', () {
      final g = ChessGame('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
      expect(g.perft(1), 14);
      expect(g.perft(2), 191);
      expect(g.perft(3), 2812);
    });

    test('4-pozitsiya (aylanish va rokirovka): 6 / 264', () {
      final g = ChessGame(
          'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
      expect(g.perft(1), 6);
      expect(g.perft(2), 264);
    });
  });

  test("Ahmoq mati: f3 e5 g4 Qh4#", () {
    final g = ChessGame();
    for (final m in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      expect(g.playUci(m), isTrue, reason: m);
    }
    expect(g.result, ChessResult.checkmate);
    expect(g.san, ['f3', 'e5', 'g4', 'Qh4#']);
  });

  test('pat', () {
    final g = ChessGame('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(g.inCheck(), isFalse);
    expect(g.result, ChessResult.stalemate);
  });

  test("en passant: urilgan piyoda olib tashlanadi", () {
    final g = ChessGame();
    for (final m in ['e2e4', 'a7a6', 'e4e5', 'd7d5']) {
      g.playUci(m);
    }
    expect(g.playUci('e5d6'), isTrue);
    expect(g.board[squareOf('d5')], '');
    expect(g.board[squareOf('d6')], 'P');
    expect(g.san.last, 'exd6');
    g.undo();
    expect(g.board[squareOf('d5')], 'p');
    expect(g.board[squareOf('e5')], 'P');
  });

  test("rokirovka: shax ostida va urilayotgan katakdan o'tib bo'lmaydi", () {
    final g = ChessGame('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    expect(g.playUci('e1g1'), isTrue);
    expect(g.board[squareOf('f1')], 'R');
    expect(g.san.last, 'O-O');

    // f1 ni qora fil uradi — qisqa rokirovka mumkin emas
    final h = ChessGame('4k3/8/8/8/8/8/6b1/R3K2R w KQ - 0 1');
    expect(h.playUci('e1g1'), isFalse);
    expect(h.playUci('e1c1'), isTrue);
  });

  test("rux qo'zg'alsa rokirovka huquqi yo'qoladi", () {
    final g = ChessGame('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    g.playUci('h1h2');
    g.playUci('a8a7');
    g.playUci('h2h1');
    g.playUci('a7a8');
    expect(g.playUci('e1g1'), isFalse);
    // h1 ruxi yurdi -> K yo'q, a8 ruxi yurdi -> q yo'q
    expect(g.castling, 'Qk');
  });

  test("piyoda aylanishi tanlanadi", () {
    final g = ChessGame('8/P7/8/8/8/8/8/k6K w - - 0 1');
    expect(g.playUci('a7a8n'), isTrue);
    expect(g.board[squareOf('a8')], 'N');
    expect(g.san.last, 'a8=N');
  });

  test('SAN: bir xil donalarni ajratish', () {
    // Ikkala rux d1 ga bora oladi -> fayl bilan ajratiladi
    final g = ChessGame('4k3/8/8/8/8/8/4K3/R6R w - - 0 1');
    g.playUci('a1d1');
    expect(g.san.last, 'Rad1');
    // Bir ustundagi ikki rux -> qator bilan ajratiladi
    final h = ChessGame('4k3/R7/8/8/8/8/4K3/R7 w - - 0 1');
    h.playUci('a1a4');
    expect(h.san.last, 'R1a4');
  });

  test('durang: uch marta takrorlanish', () {
    final g = ChessGame();
    for (var k = 0; k < 2; k++) {
      for (final m in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
        g.playUci(m);
      }
    }
    expect(g.result, ChessResult.repetition);
  });

  test("durang: matga dona yetmaydi; 50 yurish", () {
    expect(ChessGame('8/8/8/4k3/8/8/2B5/4K3 w - - 0 1').result,
        ChessResult.material);
    expect(ChessGame('8/8/8/4k3/8/8/2R5/4K3 w - - 100 80').result,
        ChessResult.fiftyMoves);
  });

  test("yurishni qaytarish boshlang'ich holatga olib keladi", () {
    final g = ChessGame();
    final before = g.board.join();
    g.playUci('e2e4');
    g.playUci('e7e5');
    g.undo();
    g.undo();
    expect(g.board.join(), before);
    expect(g.turn, 'w');
    expect(g.san, isEmpty);
  });

  test('kompyuter: 1 yurishda matni topadi (qiyin va o\'rta)', () {
    for (final level in [2, 3]) {
      final g = ChessGame('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1');
      final m = g.bestMove(level)!;
      g.play(m);
      expect(g.result, ChessResult.checkmate, reason: 'daraja $level: $m');
    }
  });

  test('kompyuter: himoyasiz farzinni oladi', () {
    final g = ChessGame('4k3/8/8/3q4/4P3/8/8/4K3 w - - 0 1');
    expect(g.bestMove(2).toString(), 'e4d5');
  });

  testWidgets("ekran: e2-e4, kompyuter javob beradi", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ChessScreen(vsAi: true, level: 1)));
    expect(find.text('Oq navbati'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sq-e2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('sq-e4')));
    await t.pump();
    expect(find.textContaining('1. e4'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump();
    expect(find.text('Oq navbati'), findsOneWidget); // kompyuter yurdi
  });
}
