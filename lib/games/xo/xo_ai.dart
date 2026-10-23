import 'dart:math';

import 'xo_game.dart';

/// X-O uchun kompyuter o'yinchi.
///
/// [level]: 1 — oson (tez-tez xato qiladi), 2 — o'rta, 3 — qiyin.
/// 3×3 da minimaks (qiyinda yutib bo'lmaydi), 10×10 da qator baholash.
int xoAiMove(XoGame g, String me, int level, [Random? rnd]) {
  final r = rnd ?? Random();
  final empty = [for (var i = 0; i < g.board.length; i++) if (g.board[i].isEmpty) i];
  if (empty.isEmpty) return -1;
  return g.size == 3
      ? _small(g.board, me, level, empty, r)
      : _big(g.board, g.size, g.winLen, me, level, r);
}

String _other(String m) => m == 'X' ? 'O' : 'X';

// ---------------------------------------------------------------- 3×3

int _small(List<String> board, String me, int level, List<int> empty, Random r) {
  // Oson: yarim holatda tasodifiy, o'rta: 25% holatda tasodifiy
  final mistake = switch (level) { 1 => 0.55, 2 => 0.2, _ => 0.0 };
  if (r.nextDouble() < mistake) return empty[r.nextInt(empty.length)];

  final b = [...board];
  var best = -1000;
  final bestMoves = <int>[];
  for (final i in empty) {
    b[i] = me;
    final s = -_negamax(b, _other(me), 1, i);
    b[i] = '';
    if (s > best) {
      best = s;
      bestMoves
        ..clear()
        ..add(i);
    } else if (s == best) {
      bestMoves.add(i);
    }
  }
  return bestMoves[r.nextInt(bestMoves.length)];
}

/// [turn] navbatidagi o'yinchi nuqtai nazaridan baho. Tezroq yutish yaxshiroq.
int _negamax(List<String> b, String turn, int depth, int last) {
  if (XoGame.winningLine(b, 3, 3, last) != null) return -(10 - depth);
  if (!b.contains('')) return 0;
  var best = -1000;
  for (var i = 0; i < 9; i++) {
    if (b[i].isNotEmpty) continue;
    b[i] = turn;
    final s = -_negamax(b, _other(turn), depth + 1, i);
    b[i] = '';
    if (s > best) best = s;
  }
  return best;
}

// ---------------------------------------------------------------- 10×10

const _dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];

/// [i] katakka [mark] qo'yilsa, hosil bo'ladigan qatorlar bahosi.
double _lineScore(List<String> b, int size, int winLen, int i, String mark) {
  final r0 = i ~/ size, c0 = i % size;
  var total = 0.0;
  var fours = 0, openThrees = 0;
  for (final (dr, dc) in _dirs) {
    var count = 1, open = 0;
    for (final s in const [1, -1]) {
      var r = r0 + dr * s, c = c0 + dc * s;
      while (r >= 0 && r < size && c >= 0 && c < size && b[r * size + c] == mark) {
        count++;
        r += dr * s;
        c += dc * s;
      }
      if (r >= 0 && r < size && c >= 0 && c < size && b[r * size + c].isEmpty) open++;
    }
    if (count >= winLen) {
      total += 1e6;
    } else if (open > 0) {
      final k = winLen - count; // nechta yetishmaydi
      total += switch ((k, open)) {
        (1, 2) => 5e4,
        (1, _) => 3000,
        (2, 2) => 2500,
        (2, _) => 200,
        (3, 2) => 120,
        (3, _) => 15,
        _ => open * 2.0,
      };
      if (k == 1) fours++;
      if (k == 2 && open == 2) openThrees++;
    }
  }
  // Ikki tomonlama tahdid (vilka) — deyarli yutuq
  if (fours >= 2 || (fours >= 1 && openThrees >= 1)) total += 4e4;
  if (openThrees >= 2) total += 8000;
  return total;
}

int _big(List<String> b, int size, int winLen, String me, int level, Random r) {
  final opp = _other(me);
  final stones = [for (var i = 0; i < b.length; i++) if (b[i].isNotEmpty) i];
  if (stones.isEmpty) {
    final c = size ~/ 2;
    return (c - r.nextInt(2)) * size + c - r.nextInt(2);
  }

  // Faqat mavjud toshlar yonidagi kataklar ko'rib chiqiladi
  final cand = <int>{};
  for (final s in stones) {
    final r0 = s ~/ size, c0 = s % size;
    for (var dr = -2; dr <= 2; dr++) {
      for (var dc = -2; dc <= 2; dc++) {
        final rr = r0 + dr, cc = c0 + dc;
        if (rr < 0 || rr >= size || cc < 0 || cc >= size) continue;
        if (b[rr * size + cc].isEmpty) cand.add(rr * size + cc);
      }
    }
  }

  final defense = switch (level) { 1 => 0.35, 2 => 0.85, _ => 1.0 };
  final noise = switch (level) { 1 => 0.9, 2 => 0.25, _ => 0.0 };
  final scored = <(int, double)>[];
  for (final i in cand) {
    final attack = _lineScore(b, size, winLen, i, me);
    final block = _lineScore(b, size, winLen, i, opp);
    // Yutuq har doim birinchi; qiyinda yutqazishni ham doim to'sadi
    var s = attack * 1.1 + block * defense;
    if (attack >= 1e6) s = 1e9;
    if (noise > 0) s *= 1 + (r.nextDouble() * 2 - 1) * noise;
    scored.add((i, s));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  if (level == 1 && scored.length > 3 && scored.first.$2 < 1e9 && r.nextDouble() < 0.3) {
    return scored[1 + r.nextInt(3)].$1;
  }
  return scored.first.$1;
}
