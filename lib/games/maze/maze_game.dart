import 'dart:math';

/// Labirint musobaqasi.
///
/// Labirint kvadrat kataklardan iborat: har bir katak yo devor, yo yo'lak.
/// [n] xonali labirint (2n+1)×(2n+1) katakka chiziladi. Tepada kirish,
/// pastda chiqish. Siz barmoq bilan yo'l chizasiz, kompyuter esa
/// yo'lni qidirib (boshi berk ko'chalarga kirib-chiqib) boradi.
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

/// Barmoq bilan chizilayotgan yo'l.
///
/// Yo'l — qo'shni (yonma-yon) yo'lak kataklari ketma-ketligi. Barmoq har
/// siljiganda oraliq nuqtalar ham tekshiriladi: tez sursangiz ham devorni
/// "sakrab" o'tib bo'lmaydi.
class PlayerPath {
  final Maze maze;
  final cells = <int>[];

  /// Hozir barmoq chizyaptimi (devorga tegsa — uziladi).
  bool drawing = false;

  /// Oxirgi barmoq nuqtasi (katak birligida).
  double _lx = 0, _ly = 0;

  PlayerPath(this.maze) {
    cells.add(maze.start);
  }

  int get end => cells.last;
  bool get finished => end == maze.exit;

  /// Barmoq qo'yildi. Yo'l ustiga (yoki uchiga yaqin) qo'yilsa — chizish boshlanadi
  /// va yo'l o'sha joygacha qisqaradi.
  bool begin(double x, double y) {
    if (finished) return false;
    final r = y.floor(), c = x.floor();
    var hit = -1;
    // Barmoq ostidagi katak yoki uning qo'shnisi yo'lda bo'lsa
    for (final (dr, dc) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final i = (r + dr) * maze.size + (c + dc);
      if (maze.isWall(r + dr, c + dc)) continue;
      final at = cells.lastIndexOf(i);
      if (at > hit) hit = at;
    }
    if (hit < 0) return false;
    cells.removeRange(hit + 1, cells.length);
    drawing = true;
    _lx = maze.col(end) + 0.5;
    _ly = maze.row(end) + 0.5;
    return true;
  }

  /// Barmoq siljidi. Devorga tegsa false qaytaradi va chizish uziladi.
  bool move(double x, double y) {
    if (!drawing) return true;
    final dx = x - _lx, dy = y - _ly;
    final steps = max(1, (sqrt(dx * dx + dy * dy) / 0.2).ceil());
    for (var k = 1; k <= steps; k++) {
      final px = _lx + dx * k / steps, py = _ly + dy * k / steps;
      final r = py.floor(), c = px.floor();
      if (maze.isWall(r, c)) {
        drawing = false;
        return false;
      }
      if (!_enter(r * maze.size + c)) {
        drawing = false;
        return false;
      }
      if (finished) {
        drawing = false;
        return true;
      }
    }
    _lx = x;
    _ly = y;
    return true;
  }

  void stop() => drawing = false;

  /// Yangi katakka o'tish. Orqaga qaytsa — yo'l qisqaradi.
  bool _enter(int i) {
    if (i == end) return true;
    final back = cells.length >= 2 ? cells[cells.length - 2] : -1;
    if (i == back) {
      cells.removeLast();
      return true;
    }
    final r0 = maze.row(end), c0 = maze.col(end);
    final r1 = maze.row(i), c1 = maze.col(i);
    final dr = r1 - r0, dc = c1 - c0;
    if (dr.abs() + dc.abs() == 1) {
      _push(i);
      return true;
    }
    // Diagonal: burchakdan kesib o'tmaslik uchun oradagi ochiq katak orqali
    if (dr.abs() == 1 && dc.abs() == 1) {
      for (final (mr, mc) in [(r0 + dr, c0), (r0, c0 + dc)]) {
        if (!maze.isWall(mr, mc)) {
          _enter(mr * maze.size + mc);
          _enter(i);
          return true;
        }
      }
    }
    return false;
  }

  void _push(int i) {
    // Halqa bo'lsa — o'sha joygacha qisqartiramiz
    final at = cells.indexOf(i);
    if (at >= 0) {
      cells.removeRange(at + 1, cells.length);
    } else {
      cells.add(i);
    }
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
