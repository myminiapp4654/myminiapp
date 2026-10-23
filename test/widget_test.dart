import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim_core/oyinim_core.dart';

void main() {
  test("So'z topish: har bir jumboqda 3 ta so'z, faqat katta harflar", () {
    for (final puzzle in kWordPuzzles) {
      final words = puzzle['words'] as List;
      expect(words.length, 3);
      for (final w in words) {
        final word = (w as Map)['word'] as String;
        expect(RegExp(r'^[A-Z]+$').hasMatch(word), isTrue, reason: word);
        expect((w['hint'] as String).isNotEmpty, isTrue, reason: word);
      }
    }
  });

  test("Viktorina: to'g'ri javob indeksi variantlar ichida", () {
    for (final q in kQuestions) {
      final options = q['o'] as List;
      final correct = q['c'] as int;
      expect(options.length, 4, reason: q['q'] as String);
      expect(correct >= 0 && correct < options.length, isTrue,
          reason: q['q'] as String);
    }
  });

  test("Harflar o'yini: so'zlar faqat katta harflardan", () {
    for (final w in kScrambleWords) {
      expect(RegExp(r'^[A-Z]+$').hasMatch(w['word']!), isTrue, reason: w['word']);
    }
  });

  test("Shashka: boshida oq 7 ta yura oladi, urish yo'q", () {
    final board = CheckersRules.initialBoard();
    var moves = 0;
    for (var i = 0; i < 64; i++) {
      if (board[i] == 'w') moves += CheckersRules.validMoves(board, i, -1).length;
    }
    expect(moves, 7);
    expect(CheckersRules.anyJump(board, 'w'), isFalse);
  });
}
