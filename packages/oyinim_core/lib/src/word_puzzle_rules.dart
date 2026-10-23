import 'dart:math';

class WordPuzzleRules {
  WordPuzzleRules._();

  static const maxWrong = 5;
  static const tileCount = 20;

  /// Jumboqdagi so'zlar (bo'sh so'zlarsiz).
  static List<String> wordsOf(Map puzzle) => (puzzle['words'] as List)
      .map((w) => (w as Map)['word'] as String)
      .where((w) => w.isNotEmpty)
      .toList();

  /// Kerakli harflar + tasodifiy qo'shimcha harflar, jami ~20 ta.
  static List<String> buildTiles(Map puzzle, [Random? random]) {
    final rnd = random ?? Random();
    final needed = <String>{};
    for (final word in wordsOf(puzzle)) {
      needed.addAll(word.split(''));
    }
    const all = 'ABCDEFGHIJKLMNOPQRSTUVXYZ';
    final extra = all.split('').where((c) => !needed.contains(c)).toList()
      ..shuffle(rnd);
    final tiles = [...needed];
    final fill = tileCount - tiles.length;
    if (fill > 0) tiles.addAll(extra.take(fill));
    tiles.shuffle(rnd);
    return tiles;
  }

  static bool isSolved(Map puzzle, List<String> revealed) {
    final letters = wordsOf(puzzle).join().split('').toSet();
    return letters.isNotEmpty && letters.every(revealed.contains);
  }
}
