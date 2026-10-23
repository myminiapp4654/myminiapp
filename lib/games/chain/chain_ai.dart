import 'dart:math';

import 'chain_game.dart';

/// Chain Reaction uchun kompyuter: hozirgi o'yinchi qayerga shar qo'yadi.
///
/// [level]: 1 — oson, 2 — o'rta (bir yurish oldinni baholaydi),
/// 3 — qiyin (keyingi raqibning eng yaxshi javobini ham hisobga oladi).
int chainAiMove(ChainGame g, int level, [Random? rnd]) {
  final r = rnd ?? Random();
  final me = g.current;
  final moves = [for (var i = 0; i < g.cells; i++) if (g.canPlace(i)) i];
  if (moves.isEmpty) return -1;
  if (level <= 1 && r.nextDouble() < 0.45) return moves[r.nextInt(moves.length)];

  var best = -double.infinity;
  final bestMoves = <int>[];
  for (final m in moves) {
    final after = g.copy()..play(m);
    var s = level >= 3 ? _afterReply(after, me) : chainEval(after, me);
    if (level <= 1) s += r.nextDouble() * 6;
    if (s > best) {
      best = s;
      bestMoves
        ..clear()
        ..add(m);
    } else if (s == best) {
      bestMoves.add(m);
    }
  }
  return bestMoves[r.nextInt(bestMoves.length)];
}

/// Keyingi o'yinchi o'zi uchun eng yaxshi yurishni qilgandan keyingi baho.
double _afterReply(ChainGame g, int me) {
  if (g.finished) return chainEval(g, me);
  final opp = g.current;
  ChainGame? worst;
  var oppBest = -double.infinity;
  for (var i = 0; i < g.cells; i++) {
    if (!g.canPlace(i)) continue;
    final after = g.copy()..play(i);
    final s = chainEval(after, opp);
    if (s > oppBest) {
      oppBest = s;
      worst = after;
    }
  }
  return chainEval(worst ?? g, me);
}

/// [me] uchun pozitsiya bahosi.
double chainEval(ChainGame g, int me) {
  if (g.finished) return g.winner == me ? 1e6 : -1e6;
  final mine = g.orbsOf(me);
  if (g.hasMoved[me] && mine == 0) return -1e6;

  var enemyOrbs = 0;
  for (var i = 0; i < g.cells; i++) {
    if (g.owner[i] >= 0 && g.owner[i] != me) enemyOrbs += g.count[i];
  }

  var score = 0.0;
  for (var i = 0; i < g.cells; i++) {
    if (g.owner[i] != me) continue;
    score += g.count[i];
    final cap = g.capacity(i);
    var safe = true;
    for (final n in g.neighbors(i)) {
      if (g.owner[n] >= 0 && g.owner[n] != me && g.isCritical(n)) {
        // Raqib portlashi yonida — bu katak xavf ostida
        score -= 5 - g.capacity(n);
        safe = false;
      }
    }
    if (safe) {
      if (cap == 2) score += 3; // burchak
      if (cap == 3) score += 2; // chet
      if (g.isCritical(i)) score += 2;
    }
  }

  // Bir-biriga ulangan portlashga tayyor kataklar zanjiri
  final seen = <int>{};
  for (var i = 0; i < g.cells; i++) {
    if (seen.contains(i) || g.owner[i] != me || !g.isCritical(i)) continue;
    var size = 0;
    final stack = [i];
    seen.add(i);
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      size++;
      for (final n in g.neighbors(c)) {
        if (!seen.contains(n) && g.owner[n] == me && g.isCritical(n)) {
          seen.add(n);
          stack.add(n);
        }
      }
    }
    if (size > 1) score += 2.0 * size;
  }

  return score + mine - enemyOrbs * 0.8;
}
