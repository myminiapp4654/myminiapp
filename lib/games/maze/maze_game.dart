import 'dart:math';

/// Labirint musobaqasi.
///
/// Labirint kvadrat kataklardan iborat: har bir katak yo devor, yo yo'lak.
/// [n] xonali labirint (2n+1)×(2n+1) katakka chiziladi. Tepada kirish,
/// pastda chiqish. Siz surib boshqarasiz: o'yinchi devorgacha yoki birinchi
/// burilishgacha o'zi yuradi. Kompyuter esa yo'lni qidirib (boshi berk
/// ko'chalarga kirib-chiqib) boradi.
class Maze {
  final int size; // kataklar soni (bir tomonda)
  final List<bool> wall;
  final int start; // tepadagi kirish katagi
  final int exit; // pastdagi chiqish katagi

  Maze._(this.size, this.wall, this.start, this.exit);

  /// Daraja bo'yicha xonalar soni: 12 → 25×25, 14 → 29×29, 16 → 33×33.
  static int roomsFor(int level) => switch (level) {
    1 => 12,
    2 => 14,
    _ => 16,
  };

  /// "Rekursiv orqaga qaytish" usuli: uzun, chalkash yo'laklar.
  factory Maze.generate(int rooms, Random r) {
    final size = rooms * 2 + 1;
    final wall = List.filled(size * size, true);
    final seen = List.filled(rooms * rooms, false);
    int tile(int rr, int cc) => (rr * 2 + 1) * size + (cc * 2 + 1);

    final stack = <int>[r.nextInt(rooms * rooms)];
    seen[stack.first] = true;
    wall[tile(stack.first ~/ rooms, stack.first % rooms)] = false;
    while (stack.isNotEmpty) {
      final cur = stack.last;
      final cr = cur ~/ rooms, cc = cur % rooms;
      final next = <(int, int)>[
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)])
          if (cr + dr >= 0 &&
              cr + dr < rooms &&
              cc + dc >= 0 &&
              cc + dc < rooms &&
              !seen[(cr + dr) * rooms + cc + dc])
            (cr + dr, cc + dc),
      ];
      if (next.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (nr, nc) = next[r.nextInt(next.length)];
      // Oradagi devorni buzamiz
      wall[(cr * 2 + 1 + (nr - cr)) * size + (cc * 2 + 1 + (nc - cc))] = false;
      wall[tile(nr, nc)] = false;
      seen[nr * rooms + nc] = true;
      stack.add(nr * rooms + nc);
    }

    // Kirish — tepada, chiqish — pastda (ikkalasi har xil ustunda)
    final startCol = r.nextInt(rooms) * 2 + 1;
    var exitCol = r.nextInt(rooms) * 2 + 1;
    if (rooms > 2) {
      while ((exitCol - startCol).abs() < size ~/ 3) {
        exitCol = r.nextInt(rooms) * 2 + 1;
      }
    }
    final start = startCol;
    final exit = (size - 1) * size + exitCol;
    wall[start] = false;
    wall[exit] = false;
    return Maze._(size, wall, start, exit);
  }

  /// Testlar uchun: matndan labirint ('#' — devor, 'S' — kirish, 'E' — chiqish).
  factory Maze.parse(List<String> rows) {
    final size = rows.length;
    final wall = <bool>[];
    var start = -1, exit = -1;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final ch = rows[r][c];
        wall.add(ch == '#');
        if (ch == 'S') start = r * size + c;
        if (ch == 'E') exit = r * size + c;
      }
    }
    return Maze._(size, wall, start, exit);
  }

  int row(int i) => i ~/ size;
  int col(int i) => i % size;

  bool isWall(int r, int c) =>
      r < 0 || r >= size || c < 0 || c >= size || wall[r * size + c];

  List<int> neighbors(int i) {
    final r = row(i), c = col(i);
    return [
      for (final (dr, dc) in const [(1, 0), (0, 1), (0, -1), (-1, 0)])
        if (!isWall(r + dr, c + dc)) (r + dr) * size + c + dc,
    ];
  }

  /// Eng qisqa yo'l (kirishdan chiqishgacha) — testlar va baholash uchun.
  List<int> shortestPath() {
    final prev = List.filled(size * size, -1);
    final queue = [start];
    prev[start] = start;
    for (var k = 0; k < queue.length; k++) {
      final cur = queue[k];
      if (cur == exit) break;
      for (final n in neighbors(cur)) {
        if (prev[n] == -1) {
          prev[n] = cur;
          queue.add(n);
        }
      }
    }
    if (prev[exit] == -1) return const [];
    final path = [exit];
    while (path.last != start) {
      path.add(prev[path.last]);
    }
    return path.reversed.toList();
  }
}

/// O'yinchi: surilgan tomonga sirpanib yuradi.
///
/// To'xtaydi: devorga yetganda, chiqishga yetganda yoki yonida burilish
/// (yon tomonga ochiq yo'l) chiqqanda — burilishdan o'tib ketmaslik uchun.
class MazeWalker {
  final Maze maze;

  /// Bosib o'tilgan yo'l (orqaga qaytilsa — qisqaradi).
  final cells = <int>[];

  MazeWalker(this.maze) {
    cells.add(maze.start);
  }

  int get at => cells.last;
  bool get finished => at == maze.exit;

  /// [dr],[dc] tomonga yurish mumkinmi.
  bool canGo(int dr, int dc) =>
      !maze.isWall(maze.row(at) + dr, maze.col(at) + dc);

  /// Shu tomonga sirpanganda bosib o'tiladigan kataklar (bo'sh — yurib bo'lmaydi).
  List<int> slide(int dr, int dc) {
    final out = <int>[];
    var r = maze.row(at), c = maze.col(at);
    while (!maze.isWall(r + dr, c + dc)) {
      r += dr;
      c += dc;
      final i = r * maze.size + c;
      out.add(i);
      if (i == maze.exit) break;
      // Yonida ochiq yo'l — burilish joyi, to'xtaymiz
      final side = dr != 0
          ? !maze.isWall(r, c - 1) || !maze.isWall(r, c + 1)
          : !maze.isWall(r - 1, c) || !maze.isWall(r + 1, c);
      if (side) break;
    }
    return out;
  }

  /// Qo'shni katakka o'tish (iz yangilanadi).
  void step(int i) {
    if (cells.length >= 2 && cells[cells.length - 2] == i) {
      cells.removeLast(); // orqaga qaytdi — iz o'chadi
      return;
    }
    final at = cells.indexOf(i);
    if (at >= 0) {
      cells.removeRange(at + 1, cells.length);
    } else {
      cells.add(i);
    }
  }

  /// Sirpanishni darhol bajarish (testlar va hisob-kitob uchun).
  List<int> go(int dr, int dc) {
    final path = slide(dr, dc);
    path.forEach(step);
    return path;
  }
}

/// Kompyuter: chuqurlikka qidirish. Har qadamda bitta katak oldinga
/// yoki boshi berk ko'chadan bitta katak orqaga.
///
/// Butun qidiruv oldindan hisoblanadi, tezlik esa shunday tanlanadiki,
/// kompyuter omadi kelsa ham, kelmasa ham taxminan bir xil vaqtda chiqadi.
class MazeRunner {
  final Maze maze;
  final int level;
  final stack = <int>[];
  final visited = <int>{};

  /// Qadamlar: katak raqami — oldinga, -1 — orqaga.
  final _events = <int>[];
  int _next = 0;

  /// Sekundiga necha qadam.
  late final double speed;

  MazeRunner(this.maze, this.level, Random r) {
    stack.add(maze.start);
    visited.add(maze.start);
    _plan(r);
    // Mo'ljal: eng qisqa yo'l uzunligiga qarab (soniya)
    final target =
        maze.shortestPath().length /
        switch (level) {
          1 => 2.0,
          2 => 3.0,
          _ => 4.2,
        };
    speed = (_events.length / target).clamp(3.0, 30.0);
  }

  bool get finished => stack.last == maze.exit;

  void _plan(Random r) {
    final st = [maze.start];
    final seen = {maze.start};
    int dist(int i) =>
        (maze.row(i) - maze.row(maze.exit)).abs() +
        (maze.col(i) - maze.col(maze.exit)).abs();
    // Qiyin kompyuter ko'pincha chiqish tomonga qarab yuradi
    final smart = switch (level) {
      1 => 0.0,
      2 => 0.35,
      _ => 0.7,
    };
    while (st.last != maze.exit) {
      final options = [
        for (final n in maze.neighbors(st.last))
          if (!seen.contains(n)) n,
      ];
      if (options.isEmpty) {
        st.removeLast();
        _events.add(-1);
        continue;
      }
      final int pick;
      if (r.nextDouble() < smart) {
        options.sort((a, b) => dist(a).compareTo(dist(b)));
        pick = options.first;
      } else {
        pick = options[r.nextInt(options.length)];
      }
      seen.add(pick);
      st.add(pick);
      _events.add(pick);
    }
  }

  void step() {
    if (finished || _next >= _events.length) return;
    final e = _events[_next++];
    if (e < 0) {
      stack.removeLast();
    } else {
      stack.add(e);
      visited.add(e);
    }
  }
}
