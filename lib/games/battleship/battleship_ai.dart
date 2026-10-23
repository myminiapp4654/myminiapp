import 'dart:math';

import 'battleship_game.dart';

/// Dengiz jangi uchun kompyuter: [shooter] qayerga otishini tanlaydi.
///
/// Kompyuter faqat o'zi ko'rgan narsani biladi: qayerga otgan, tekdimi,
/// qaysi kema portladi. [level]: 1 — oson, 2 — o'rta, 3 — qiyin.
int battleshipAiShot(BattleshipGame g, int shooter, int level, [Random? rnd]) {
  final r = rnd ?? Random();
  final fired = g.shots[shooter];
  final marked = g.autoMarked[shooter];
  final enemy = g.fleets[1 - shooter];
  bool free(int c) => !fired.contains(c) && !marked.contains(c);

  final open = [for (var i = 0; i < kCells; i++) if (free(i)) i];
  if (open.isEmpty) return -1;

  // Tekkan, lekin hali portlamagan kema kataklari
  final wounded = <int>[
    for (final c in fired)
      if (enemy.shipAt(c) case final s? when !s.cells.every(fired.contains)) c,
  ]..sort();

  // Oson kompyuter ba'zan yaradorni "unutadi"
  final chase = wounded.isNotEmpty && !(level == 1 && r.nextDouble() < 0.8);
  if (chase) {
    final targets = _chaseTargets(wounded, free);
    if (targets.isNotEmpty) return targets[r.nextInt(targets.length)];
  }

  // Qolgan kemalar sig'ishi mumkin bo'lgan joylar zichligi
  final left = List.of(kFleet);
  for (final s in enemy.ships) {
    if (s.cells.every(fired.contains)) left.remove(s.length);
  }
  final heat = List.filled(kCells, 0);
  for (final len in left) {
    for (var start = 0; start < kCells; start++) {
      for (final h in const [true, false]) {
        if (len == 1 && !h) continue;
        final cells = Fleet.cellsFor(start, len, h);
        if (cells == null || !cells.every(free)) continue;
        for (final c in cells) {
          heat[c]++;
        }
      }
    }
  }

  // Oson va o'rta: tasodifiy
  if (level <= 2) return open[r.nextInt(open.length)];

  // Qiyin: eng ehtimolli katak
  var best = -1;
  final bestCells = <int>[];
  for (final c in open) {
    if (heat[c] > best) {
      best = heat[c];
      bestCells
        ..clear()
        ..add(c);
    } else if (heat[c] == best) {
      bestCells.add(c);
    }
  }
  return bestCells[r.nextInt(bestCells.length)];
}

/// Yarador kema davomini qidirish: chiziq ma'lum bo'lsa — uchlariga,
/// aks holda to'rt tomonga.
List<int> _chaseTargets(List<int> wounded, bool Function(int) free) {
  // Bir kemaga tegishli bo'lgan qo'shni kataklar guruhini olamiz
  final group = <int>{wounded.first};
  var grew = true;
  while (grew) {
    grew = false;
    for (final c in wounded) {
      if (group.contains(c)) continue;
      if (group.any((g) => _adjacent(g, c))) {
        group.add(c);
        grew = true;
      }
    }
  }
  final cells = group.toList()..sort();
  final rows = cells.map((c) => c ~/ kBoardSize).toSet();
  final cols = cells.map((c) => c % kBoardSize).toSet();
  final out = <int>[];

  void tryAdd(int r, int c) {
    if (r < 0 || r >= kBoardSize || c < 0 || c >= kBoardSize) return;
    final i = r * kBoardSize + c;
    if (free(i)) out.add(i);
  }

  if (cells.length >= 2 && rows.length == 1) {
    final r = rows.first;
    tryAdd(r, cols.reduce(min) - 1);
    tryAdd(r, cols.reduce(max) + 1);
  } else if (cells.length >= 2 && cols.length == 1) {
    final c = cols.first;
    tryAdd(rows.reduce(min) - 1, c);
    tryAdd(rows.reduce(max) + 1, c);
  } else {
    final r = cells.first ~/ kBoardSize, c = cells.first % kBoardSize;
    tryAdd(r - 1, c);
    tryAdd(r + 1, c);
    tryAdd(r, c - 1);
    tryAdd(r, c + 1);
  }
  return out;
}

bool _adjacent(int a, int b) {
  final dr = (a ~/ kBoardSize - b ~/ kBoardSize).abs();
  final dc = (a % kBoardSize - b % kBoardSize).abs();
  return dr + dc == 1;
}
