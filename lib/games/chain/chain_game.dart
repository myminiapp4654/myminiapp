/// Chain Burst (Chain Reaction): 2–8 o'yinchi, bitta telefonda.
///
/// - Navbat bilan bo'sh yoki o'z rangingizdagi katakka shar qo'yasiz
/// - Katakdagi sharlar soni uning qo'shnilari soniga yetsa (burchak 2, chet 3,
///   o'rta 4) — katak portlaydi: har bir qo'shniga bitta shar uchadi va qo'shni
///   kataklar sizning rangingizga o'tadi
/// - Portlash zanjir bo'lib to'lqin-to'lqin davom etadi
/// - Hamma kamida bir marta yurgandan keyin sharlari qolmagan o'yinchi chiqadi
/// - Oxirgi qolgan o'yinchi yutadi
class ChainGame {
  final int rows;
  final int cols;
  final int players;

  /// Katak egasi (-1 — bo'sh) va undagi sharlar soni.
  late List<int> owner;
  late List<int> count;

  late int current;
  int? winner;
  late List<bool> hasMoved;

  /// Yurish davomida portlash to'lqinlari tugamagan.
  bool exploding = false;

  final List<int> score;
  int round = 0;
  int _starter = -1;

  /// Bir yurishga cheklov (cheksiz zanjirdan himoya).
  static const _maxWaves = 2000;
  int _waves = 0;

  _Snapshot? _undo;

  ChainGame({this.rows = 9, this.cols = 6, this.players = 2})
      : score = List.filled(players, 0) {
    newRound();
  }

  int get cells => rows * cols;
  bool get finished => winner != null;
  bool get canUndo => _undo != null && !exploding;

  void newRound() {
    owner = List.filled(cells, -1);
    count = List.filled(cells, 0);
    hasMoved = List.filled(players, false);
    _starter = (_starter + 1) % players;
    current = _starter;
    winner = null;
    exploding = false;
    _undo = null;
    round++;
  }

  List<int> neighbors(int i) {
    final r = i ~/ cols, c = i % cols;
    return [
      if (r > 0) i - cols,
      if (r < rows - 1) i + cols,
      if (c > 0) i - 1,
      if (c < cols - 1) i + 1,
    ];
  }

  /// Necha sharda portlaydi.
  int capacity(int i) => neighbors(i).length;

  /// Yana bitta shar tushsa portlaydi.
  bool isCritical(int i) => count[i] > 0 && count[i] == capacity(i) - 1;

  int orbsOf(int p) {
    var n = 0;
    for (var i = 0; i < cells; i++) {
      if (owner[i] == p) n += count[i];
    }
    return n;
  }

  /// O'yinchi hali o'yindami (birinchi yurishigacha har doim o'yinda).
  bool isAlive(int p) => !hasMoved[p] || orbsOf(p) > 0;

  bool canPlace(int i) =>
      !finished && !exploding && (owner[i] == -1 || owner[i] == current);

  /// Shar qo'yish. Keyin portlashlar [step] bilan bittadan to'lqin bo'lib
  /// bajariladi, oxirida [endTurn].
  bool place(int i) {
    if (!canPlace(i)) return false;
    _undo = _Snapshot(this);
    owner[i] = current;
    count[i]++;
    hasMoved[current] = true;
    exploding = true;
    _waves = 0;
    return true;
  }

  /// Portlashi kerak bo'lgan kataklar.
  List<int> unstable() => [
        for (var i = 0; i < cells; i++)
          if (count[i] >= capacity(i)) i,
      ];

  /// Bitta portlash to'lqini. Portlagan kataklarni qaytaradi (bo'sh — to'lqin yo'q).
  List<int> step() {
    if (!exploding) return const [];
    final burst = unstable();
    if (burst.isEmpty || finished || _waves >= _maxWaves) {
      return const [];
    }
    _waves++;
    for (final i in burst) {
      final p = owner[i];
      final cap = capacity(i);
      count[i] -= cap;
      if (count[i] == 0) owner[i] = -1;
      for (final n in neighbors(i)) {
        count[n]++;
        owner[n] = p;
      }
    }
    _checkWinner();
    return burst;
  }

  /// Hamma to'lqinlar tugagach chaqiriladi: navbat keyingi tirik o'yinchiga.
  void endTurn() {
    if (!exploding) return;
    // Qolgan to'lqinlarni oxirigacha bajaramiz
    while (step().isNotEmpty) {}
    exploding = false;
    _checkWinner();
    if (finished) return;
    var next = current;
    do {
      next = (next + 1) % players;
    } while (!isAlive(next));
    current = next;
  }

  /// Bir yurishni to'liq bajarish (testlar va tez o'yin uchun).
  bool play(int i) {
    if (!place(i)) return false;
    endTurn();
    return true;
  }

  void _checkWinner() {
    if (finished) return;
    // Hamma kamida bir marta yurmaguncha g'olib yo'q
    if (hasMoved.contains(false)) return;
    final alive = [
      for (var p = 0; p < players; p++)
        if (orbsOf(p) > 0) p,
    ];
    if (alive.length == 1) {
      winner = alive.single;
      score[winner!]++;
      exploding = false;
      _undo = null;
    }
  }

  /// Oxirgi yurishni bekor qilish.
  bool undo() {
    if (!canUndo) return false;
    _undo!.restore(this);
    _undo = null;
    return true;
  }
}

class _Snapshot {
  final List<int> owner;
  final List<int> count;
  final List<bool> hasMoved;
  final int current;

  _Snapshot(ChainGame g)
      : owner = List.of(g.owner),
        count = List.of(g.count),
        hasMoved = List.of(g.hasMoved),
        current = g.current;

  void restore(ChainGame g) {
    g.owner = List.of(owner);
    g.count = List.of(count);
    g.hasMoved = List.of(hasMoved);
    g.current = current;
    g.exploding = false;
  }
}
