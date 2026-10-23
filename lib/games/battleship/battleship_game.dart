import 'dart:math';

/// Dengiz jangi: 9×9 taxta (ustunlar a–i, qatorlar 1–9), bitta telefonda ikki kishi.
///
/// Har bir o'yinchida 10 ta kema: 4 katakli ×1, 3 katakli ×2, 2 katakli ×3, 1 katakli ×4.
/// Kemalar gorizontal yoki vertikal, bir-biriga tegib turmaydi (burchakdan ham).
/// Tekkan o'yinchi yana otadi, tegmasa navbat almashadi.
const kBoardSize = 9;
const kCells = kBoardSize * kBoardSize;
const kFleet = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
const _columns = 'abcdefghi';

/// Katak nomi: 0 -> "a1", 80 -> "i9".
String cellName(int i) => '${_columns[i % kBoardSize]}${i ~/ kBoardSize + 1}';

class Ship {
  final List<int> cells;
  const Ship(this.cells);
  int get length => cells.length;
}

/// Bitta o'yinchining kemalari.
class Fleet {
  final ships = <Ship>[];

  /// Hali joylashtirilmagan kemalar uzunliklari (kattasidan boshlab).
  List<int> get remaining {
    final left = List.of(kFleet);
    for (final s in ships) {
      left.remove(s.length);
    }
    return left;
  }

  bool get complete => remaining.isEmpty;

  /// Kema joylashgan kataklar (yoki null — taxtadan chiqib ketsa).
  static List<int>? cellsFor(int start, int length, bool horizontal) {
    final r = start ~/ kBoardSize, c = start % kBoardSize;
    if (horizontal && c + length > kBoardSize) return null;
    if (!horizontal && r + length > kBoardSize) return null;
    return [
      for (var k = 0; k < length; k++)
        horizontal ? start + k : start + k * kBoardSize,
    ];
  }

  Ship? shipAt(int cell) =>
      ships.where((s) => s.cells.contains(cell)).firstOrNull;

  /// Katak va uning 8 ta qo'shnisi.
  static Iterable<int> around(int cell) sync* {
    final r = cell ~/ kBoardSize, c = cell % kBoardSize;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final rr = r + dr, cc = c + dc;
        if (rr >= 0 && rr < kBoardSize && cc >= 0 && cc < kBoardSize) {
          yield rr * kBoardSize + cc;
        }
      }
    }
  }

  bool canPlace(int start, int length, bool horizontal) {
    if (!remaining.contains(length)) return false;
    final cells = cellsFor(start, length, horizontal);
    if (cells == null) return false;
    // Boshqa kemaga tegmasligi kerak (burchakdan ham)
    for (final cell in cells) {
      for (final n in around(cell)) {
        if (shipAt(n) != null) return false;
      }
    }
    return true;
  }

  bool place(int start, int length, bool horizontal) {
    if (!canPlace(start, length, horizontal)) return false;
    ships.add(Ship(cellsFor(start, length, horizontal)!));
    return true;
  }

  /// Katakdagi kemani olib tashlaydi (qayta joylashtirish uchun).
  bool removeAt(int cell) {
    final ship = shipAt(cell);
    if (ship == null) return false;
    ships.remove(ship);
    return true;
  }

  void clear() => ships.clear();

  /// Hamma kemani tasodifiy joylashtiradi.
  void randomize([Random? random]) {
    final rnd = random ?? Random();
    while (true) {
      clear();
      var ok = true;
      for (final length in kFleet) {
        var placed = false;
        for (var attempt = 0; attempt < 200 && !placed; attempt++) {
          placed = place(rnd.nextInt(kCells), length, rnd.nextBool());
        }
        if (!placed) {
          ok = false;
          break;
        }
      }
      if (ok) return;
    }
  }
}

enum ShotResult { miss, hit, sunk, repeat }

enum Phase { placing, battle, finished }

class BattleshipGame {
  final fleets = [Fleet(), Fleet()];

  /// shots[i] — i-o'yinchi raqib taxtasiga otgan kataklar.
  final shots = [<int>{}, <int>{}];

  /// Kema portlaganda atrofidagi avtomatik "bo'sh" deb belgilangan kataklar.
  final autoMarked = [<int>{}, <int>{}];

  Phase phase = Phase.placing;

  /// Joylashtirish bosqichida — kim joylashtiryapti; jangda — kim otadi.
  int current = 0;
  int? winner;
  final score = [0, 0];
  int round = 1;

  /// Raund boshlovchisi (har raundda almashadi).
  int _starter = 0;

  int get opponent => 1 - current;

  /// Joriy o'yinchi kemalarini joylashtirib bo'ldi.
  /// Ikkalasi ham tayyor bo'lsa — jang boshlanadi.
  bool finishPlacing() {
    if (phase != Phase.placing || !fleets[current].complete) return false;
    if (current == _starter) {
      current = 1 - _starter;
    } else {
      phase = Phase.battle;
      current = _starter;
    }
    return true;
  }

  /// Joriy o'yinchi raqib taxtasidagi [cell] ga otadi.
  ShotResult fire(int cell) {
    if (phase != Phase.battle) return ShotResult.repeat;
    final fired = shots[current];
    if (fired.contains(cell) || autoMarked[current].contains(cell)) {
      return ShotResult.repeat;
    }
    fired.add(cell);

    final ship = fleets[opponent].shipAt(cell);
    if (ship == null) {
      current = opponent; // tegmadi — navbat almashadi
      return ShotResult.miss;
    }
    if (!ship.cells.every(fired.contains)) return ShotResult.hit;

    // Portladi: atrofidagi kataklarda kema bo'lishi mumkin emas
    for (final c in ship.cells) {
      for (final n in Fleet.around(c)) {
        if (!fired.contains(n)) autoMarked[current].add(n);
      }
    }
    if (isDefeated(opponent)) {
      winner = current;
      score[current]++;
      phase = Phase.finished;
    }
    return ShotResult.sunk;
  }

  /// [player] ning hamma kemalari portladimi.
  bool isDefeated(int player) {
    final enemyShots = shots[1 - player];
    return fleets[player]
        .ships
        .every((s) => s.cells.every(enemyShots.contains));
  }

  /// [player] ning nechta kemasi hali suzib yuribdi.
  int shipsAlive(int player) {
    final enemyShots = shots[1 - player];
    return fleets[player]
        .ships
        .where((s) => !s.cells.every(enemyShots.contains))
        .length;
  }

  /// Yangi raund: kemalar qayta joylashtiriladi, birinchi navbat almashadi.
  void newRound() {
    for (final f in fleets) {
      f.clear();
    }
    for (final s in shots) {
      s.clear();
    }
    for (final s in autoMarked) {
      s.clear();
    }
    _starter = 1 - _starter;
    current = _starter;
    winner = null;
    phase = Phase.placing;
    round++;
  }
}
