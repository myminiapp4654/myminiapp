import 'dart:math';

import 'checkers_game.dart';

/// Shashka uchun kompyuter o'yinchi.
///
/// Bir "yurish" — navbat almashguncha bo'lgan barcha qadamlar
/// (zanjirli urish bir nechta qadamdan iborat bo'ladi).
/// [level]: 1 — oson, 2 — o'rta, 3 — qiyin.
List<CheckersMove> checkersAiTurn(CheckersGame g, int level, [Random? rnd]) {
  final r = rnd ?? Random();
  final turns = _turns(g);
  if (turns.isEmpty) return const [];
  if (turns.length == 1) return turns.first.steps;

  // Oson: ko'pincha birinchi kelgan yaxshi ko'ringan yurish
  if (level <= 1 && r.nextDouble() < 0.35) {
    return turns[r.nextInt(turns.length)].steps;
  }

  final depth = switch (level) { 1 => 1, 2 => 3, _ => 5 };
  final noise = switch (level) { 1 => 80, 2 => 15, _ => 2 };
  var best = -1 << 30;
  final bestTurns = <_Turn>[];
  for (final t in turns) {
    var s = -_search(t.after, depth - 1, -1 << 30, 1 << 30);
    s += r.nextInt(noise * 2 + 1) - noise;
    if (s > best) {
      best = s;
      bestTurns
        ..clear()
        ..add(t);
    } else if (s == best) {
      bestTurns.add(t);
    }
  }
  return bestTurns[r.nextInt(bestTurns.length)].steps;
}

class _Turn {
  final List<CheckersMove> steps;
  final CheckersGame after;
  _Turn(this.steps, this.after);
}

/// Hozirgi o'yinchining barcha to'liq yurishlari.
List<_Turn> _turns(CheckersGame g) {
  final out = <_Turn>[];
  void walk(CheckersGame state, List<CheckersMove> steps) {
    for (final m in state.legalMoves()) {
      final next = state.copy()..play(m.from, m.to);
      final path = [...steps, m];
      if (!next.finished && next.turn == state.turn && next.chain != null) {
        walk(next, path);
      } else {
        out.add(_Turn(path, next));
      }
    }
  }

  walk(g, const []);
  return out;
}

/// Negamaks: navbatdagi o'yinchi nuqtai nazaridan baho.
int _search(CheckersGame g, int depth, int alpha, int beta) {
  if (g.finished) {
    if (g.winner == 'draw') return 0;
    // Yutgan tomon — hozir yurgan (navbat allaqachon almashgan)
    return g.winner == g.turn ? 100000 + depth : -100000 - depth;
  }
  if (depth <= 0) {
    // Urish majburiy bo'lsa, tinch holatgacha qidiramiz
    if (g.mustCapture && depth > -4) return _searchMoves(g, depth, alpha, beta);
    return _eval(g);
  }
  return _searchMoves(g, depth, alpha, beta);
}

int _searchMoves(CheckersGame g, int depth, int alpha, int beta) {
  final turns = _turns(g);
  if (turns.isEmpty) return -100000;
  // Ko'p dona uradigan yurishlar oldin — kesish samaraliroq
  turns.sort((a, b) => b.steps.length.compareTo(a.steps.length));
  var best = -1 << 30;
  for (final t in turns) {
    final s = -_search(t.after, depth - 1, -beta, -alpha);
    if (s > best) best = s;
    if (s > alpha) alpha = s;
    if (alpha >= beta) break;
  }
  return best;
}

/// Navbatdagi o'yinchi uchun pozitsiya bahosi.
int _eval(CheckersGame g) {
  var score = 0;
  for (var i = 0; i < 64; i++) {
    final p = g.board[i];
    if (p.isEmpty) continue;
    final white = CheckersGame.colorOf(p) == 'w';
    final r = i ~/ 8, c = i % 8;
    var v = 0;
    if (CheckersGame.isKing(p)) {
      v = 330;
      // Katta diagonaldagi damka kuchli
      if (r + c == 7) v += 15;
    } else {
      v = 100;
      final progress = white ? 7 - r : r; // oxirgi qatorga yaqinligi
      v += progress * progress;
      // Orqa qatorni ushlab turish va markaz
      if (progress == 0) v += 8;
      if (c >= 2 && c <= 5 && r >= 2 && r <= 5) v += 6;
      // Chetdagi dona urilmaydi
      if (c == 0 || c == 7) v += 4;
    }
    score += white ? v : -v;
  }
  return g.turn == 'w' ? score : -score;
}
