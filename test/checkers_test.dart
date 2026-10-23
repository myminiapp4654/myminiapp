import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/checkers/checkers_screen.dart';
import 'package:oyinim/games/checkers/checkers_game.dart';

/// Bo'sh taxtaga donalar qo'yilgan o'yin. Kalit: (qator, ustun).
CheckersGame setup(Map<(int, int), String> pieces, {String turn = 'w'}) {
  final g = CheckersGame();
  g.board = List.filled(64, '');
  pieces.forEach((pos, p) => g.board[pos.$1 * 8 + pos.$2] = p);
  g.turn = turn;
  return g;
}

int sq(int r, int c) => r * 8 + c;

Set<int> targets(CheckersGame g, int from) =>
    g.legalMoves().where((m) => m.from == from).map((m) => m.to).toSet();

void main() {
  test('boshlanishda: 12 tadan dona, oq boshlaydi, 7 ta yurish', () {
    final g = CheckersGame();
    expect(g.count('w'), 12);
    expect(g.count('b'), 12);
    expect(g.turn, 'w');
    expect(g.legalMoves().length, 7);
    expect(g.mustCapture, isFalse);
  });

  test("oddiy dona orqaga yura olmaydi", () {
    final g = setup({(4, 3): 'w'});
    expect(targets(g, sq(4, 3)), {sq(3, 2), sq(3, 4)});
  });

  test('urish majburiy: boshqa yurishlar taqiqlanadi', () {
    final g = setup({(5, 2): 'w', (4, 3): 'b', (6, 7): 'w'});
    expect(g.legalMoves().every((m) => m.isCapture), isTrue);
    expect(g.play(sq(6, 7), sq(5, 6)), isFalse);
    expect(g.play(sq(5, 2), sq(3, 4)), isTrue);
    expect(g.board[sq(4, 3)], ''); // urilgan dona olindi
    expect(g.turn, 'b');
  });

  test('oddiy dona orqaga ura oladi', () {
    final g = setup({(3, 2): 'w', (4, 3): 'b', (0, 7): 'b'});
    expect(targets(g, sq(3, 2)), {sq(5, 4)});
  });

  test('zanjirli urish: navbat o\'zgarmaydi, oxirida donalar olinadi', () {
    final g = setup({(6, 1): 'w', (5, 2): 'b', (3, 4): 'b', (0, 7): 'b'});
    expect(g.play(sq(6, 1), sq(4, 3)), isTrue);
    expect(g.chain, sq(4, 3));
    expect(g.turn, 'w');
    expect(g.board[sq(5, 2)], 'b'); // hali olinmagan
    expect(g.play(sq(4, 3), sq(2, 5)), isTrue);
    expect(g.chain, isNull);
    expect(g.board[sq(5, 2)], '');
    expect(g.board[sq(3, 4)], '');
    expect(g.turn, 'b');
  });

  test('damka uzoqqa yuradi', () {
    final g = setup({(7, 0): 'W', (0, 7): 'b'});
    // (0,7) da qora dona — diagonal oxirida, urib bo'lmaydi (orqasi yo'q)
    expect(targets(g, sq(7, 0)),
        {sq(6, 1), sq(5, 2), sq(4, 3), sq(3, 4), sq(2, 5), sq(1, 6)});
  });

  test("damka uzoqdan uradi va istalgan bo'sh katakka tushadi", () {
    final g = setup({(7, 0): 'W', (4, 3): 'b', (0, 1): 'b'});
    expect(targets(g, sq(7, 0)), {sq(3, 4), sq(2, 5), sq(1, 6), sq(0, 7)});
  });

  test("damka urishni davom ettira oladigan katakka tushishi shart", () {
    // (4,3) ni urgach, faqat (2,5) dan (3,6) ni urish mumkin
    final g = setup({(7, 0): 'W', (4, 3): 'b', (3, 6): 'b', (0, 1): 'b'});
    expect(targets(g, sq(7, 0)), {sq(2, 5)});
  });

  test("urish paytida damka bo'lsa, damka bo'lib urishni davom ettiradi", () {
    // Oq (2,1) -> (0,3) urib damka bo'ladi, keyin (1,4)ni urib (3,6)ga
    final g = setup({(2, 1): 'w', (1, 2): 'b', (1, 4): 'b', (7, 0): 'b'});
    expect(g.play(sq(2, 1), sq(0, 3)), isTrue);
    expect(g.board[sq(0, 3)], 'W');
    expect(g.chain, sq(0, 3));
    expect(targets(g, sq(0, 3)), contains(sq(2, 5)));
  });

  test('bitta donani ikki marta urib bo\'lmaydi', () {
    // Damka aylanib o'sha donaga qaytishi mumkin bo'lgan holat
    final g = setup({(5, 0): 'W', (4, 1): 'b', (1, 4): 'b', (7, 7): 'b'});
    expect(g.play(sq(5, 0), sq(3, 2)), isTrue);
    // (4,1) urilgan, lekin hali taxtada — uni qayta urib bo'lmaydi
    for (final m in g.legalMoves()) {
      expect(m.captured, isNot(sq(4, 1)));
    }
  });

  test("oddiy yurishda oxirgi qatorga yetsa damka bo'ladi", () {
    final g = setup({(1, 2): 'w', (7, 0): 'b'});
    expect(g.play(sq(1, 2), sq(0, 1)), isTrue);
    expect(g.board[sq(0, 1)], 'W');
  });

  test("raqibning oxirgi donasi urilsa — g'alaba va hisob", () {
    final g = setup({(5, 2): 'w', (4, 3): 'b'});
    g.play(sq(5, 2), sq(3, 4));
    expect(g.winner, 'w');
    expect(g.score['w'], 1);
    expect(g.legalMoves(), isEmpty);
  });

  test("raqibda yurish qolmasa — g'alaba", () {
    // Qora (0,1) dona: oldi (1,0) va (1,2) band, urib ham bo'lmaydi
    final g = setup({(0, 1): 'b', (1, 0): 'w', (2, 3): 'w', (1, 2): 'w', (7, 6): 'w'});
    // oq qandaydir yurish qiladi
    expect(g.play(sq(7, 6), sq(6, 5)), isTrue);
    expect(g.winner, 'w');
  });

  test('durang va yangi raund', () {
    final g = CheckersGame();
    g.agreeDraw();
    expect(g.winner, 'draw');
    expect(g.draws, 1);
    g.newRound();
    expect(g.round, 2);
    expect(g.finished, isFalse);
    expect(g.count('w'), 12);
  });

  testWidgets("ekran: dona tanlab yurish, navbat almashadi", (t) async {
    await t.pumpWidget(const MaterialApp(home: CheckersScreen()));
    expect(find.text('Oq navbati'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('sq-${sq(5, 2)}')));
    await t.pump();
    await t.tap(find.byKey(ValueKey('sq-${sq(4, 3)}')));
    await t.pump();
    expect(find.text('Qora navbati'), findsOneWidget);
  });
}
