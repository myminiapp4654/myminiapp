import 'dart:math';

/// Ilon va narvon.
///
/// Taxta 10×10: 1-katak pastki chap burchakda, raqamlar ilon izi (zigzag)
/// bo'ylab yuqoriga, 100 — g'alaba. Har o'yinda ilonlar va narvonlar
/// yangi joylarda bo'ladi.
///
/// Qoidalar:
///  - zar tashlanadi, tosh shuncha katak yuradi (taxtadan tashqaridan boshlanadi)
///  - narvon ostiga tushsa — tepasiga chiqadi, ilon boshiga tushsa — dumiga tushadi
///  - 100 ga aniq yetish kerak: ortiqcha qism orqaga qaytaradi (98 + 5 → 97)
class SnakesGame {
  static const size = 10;
  static const last = size * size;

  /// Narvonlar: pastki katak -> yuqori katak.
  final Map<int, int> ladders;

  /// Ilonlar: bosh -> dum.
  final Map<int, int> snakes;

  /// Har bir ilonning ko'rinishi (egilishi, to'lqinlari, rangi).
  final Map<int, SnakeLook> looks;

  final int players;

  /// O'yinchilar joyi: 0 — hali taxtaga chiqmagan.
  late final List<int> pos = List.filled(players, 0);
  int current = 0;
  int? winner;
  int? lastRoll;

  SnakesGame({
    required this.ladders,
    required this.snakes,
    required this.looks,
    this.players = 2,
  });

  /// Tasodifiy taxta bilan yangi o'yin.
  factory SnakesGame.random({int players = 2, Random? random}) {
    final b = SnakesBoard.generate(random ?? Random());
    return SnakesGame(
      ladders: b.ladders,
      snakes: b.snakes,
      looks: b.looks,
      players: players,
    );
  }

  bool get finished => winner != null;

  /// Katakning qatori (0 — pastki) va ustuni (0 — chap).
  static (int row, int col) cellRC(int n) {
    final row = (n - 1) ~/ size;
    final k = (n - 1) % size;
    final col = row.isEven ? k : size - 1 - k;
    return (row, col);
  }

  /// Zar tashlash natijasi: [steps] — tosh birma-bir bosib o'tadigan kataklar
  /// (qaytish ham), [jump] — narvon/ilon bilan tushadigan katak yoki null.
  SnakesMove roll(int value) {
    assert(value >= 1 && value <= 6);
    final p = current;
    final from = pos[p];
    final steps = <int>[];
    var cell = from;
    var dir = 1;
    for (var k = 0; k < value; k++) {
      if (cell == last) dir = -1;
      cell += dir;
      steps.add(cell);
    }
    int? jump;
    if (ladders.containsKey(cell)) jump = ladders[cell];
    if (snakes.containsKey(cell)) jump = snakes[cell];
    final to = jump ?? cell;
    pos[p] = to;
    lastRoll = value;

    if (to == last) {
      winner = p;
    } else {
      current = (current + 1) % players;
    }
    return SnakesMove(
      p,
      from,
      steps,
      jump,
      ladder: ladders.containsKey(cell),
      snake: snakes.containsKey(cell),
    );
  }
}

class SnakesMove {
  final int player;
  final int from;
  final List<int> steps;
  final int? jump;
  final bool ladder;
  final bool snake;
  const SnakesMove(
    this.player,
    this.from,
    this.steps,
    this.jump, {
    this.ladder = false,
    this.snake = false,
  });

  int get landing => steps.isEmpty ? from : steps.last;
  int get to => jump ?? landing;
}

/// Ilonning tashqi ko'rinishi.
class SnakeLook {
  /// Umumiy egilish: -1..1 (chapga yoki o'ngga bukilgan)
  final double bend;

  /// To'lqinlar soni va balandligi
  final double waves;
  final double wiggle;

  /// Rang indeksi va naqsh: 0 — yo'l-yo'l, 1 — xol-xol
  final int color;
  final int pattern;

  const SnakeLook(this.bend, this.waves, this.wiggle, this.color, this.pattern);
}

class SnakesBoard {
  final Map<int, int> ladders;
  final Map<int, int> snakes;
  final Map<int, SnakeLook> looks;
  SnakesBoard(this.ladders, this.snakes, this.looks);

  static int _row(int n) => (n - 1) ~/ SnakesGame.size;

  /// Katak markazi (katak birligida, y pastga qarab o'sadi).
  static (double, double) _center(int n) {
    final (row, col) = SnakesGame.cellRC(n);
    return (col + 0.5, SnakesGame.size - 1 - row + 0.5);
  }

  /// Ikki katak orasidagi chiziqdagi nuqtalar.
  static List<(double, double)> _samples(int a, int b) {
    final (x1, y1) = _center(a);
    final (x2, y2) = _center(b);
    return [
      for (var k = 0; k <= 12; k++)
        (x1 + (x2 - x1) * k / 12, y1 + (y2 - y1) * k / 12),
    ];
  }

  /// Tasodifiy, lekin adolatli va tartibli taxta: 6 ta narvon, 6 ta ilon.
  /// Hech qaysi katakda ikkita uch yo'q, ilon va narvonlar bir-biridan uzoqroq.
  static SnakesBoard generate(Random r) {
    final used = <int>{1, SnakesGame.last};
    final ladders = <int, int>{};
    final snakes = <int, int>{};
    final looks = <int, SnakeLook>{};
    final placed = <List<(double, double)>>[];

    bool free(int n) => n > 1 && n < SnakesGame.last && !used.contains(n);

    /// Yangi chiziq boshqalaridan [gap] katakdan yaqin kelmaydimi.
    bool apart(List<(double, double)> line, double gap) {
      for (final other in placed) {
        for (final (x1, y1) in line) {
          for (final (x2, y2) in other) {
            final dx = x1 - x2, dy = y1 - y2;
            if (dx * dx + dy * dy < gap * gap) return false;
          }
        }
      }
      return true;
    }

    /// Joy topib qo'yadi: avval keng oraliq bilan, topilmasa — torroq.
    void place(bool ladder, int rows) {
      for (final gap in const [1.15, 0.8, 0.0]) {
        for (var attempt = 0; attempt < 300; attempt++) {
          final int a, b; // narvon: past->tepa, ilon: bosh->dum
          if (ladder) {
            a = 2 + r.nextInt(89); // 2..90
            final topRow = _row(a) + rows + (r.nextBool() ? 0 : 1);
            if (topRow > 9) continue;
            b = topRow * 10 + 1 + r.nextInt(10);
          } else {
            a = 12 + r.nextInt(88); // 12..99
            final tailRow = _row(a) - rows - (r.nextBool() ? 0 : 1);
            if (tailRow < 0) continue;
            b = tailRow * 10 + 1 + r.nextInt(10);
          }
          if (!free(a) || !free(b)) continue;
          final (_, c1) = SnakesGame.cellRC(a);
          final (_, c2) = SnakesGame.cellRC(b);
          if ((c1 - c2).abs() > (ladder ? 3 : 4)) continue;
          final line = _samples(a, b);
          if (!apart(line, gap)) continue;

          placed.add(line);
          used
            ..add(a)
            ..add(b);
          if (ladder) {
            ladders[a] = b;
          } else {
            snakes[a] = b;
            looks[a] = SnakeLook(
              r.nextDouble() * 2 - 1,
              2 + r.nextInt(3).toDouble(),
              0.1 + r.nextDouble() * 0.12,
              r.nextInt(6),
              r.nextInt(2),
            );
          }
          return;
        }
      }
    }

    // Uzunlari birinchi — ularga joy kerak
    const ladderRows = [4, 3, 2, 2, 1, 1];
    const snakeRows = [5, 4, 3, 2, 1, 1];
    for (var k = 0; k < 6; k++) {
      place(false, snakeRows[k]);
      place(true, ladderRows[k]);
    }
    return SnakesBoard(ladders, snakes, looks);
  }
}
