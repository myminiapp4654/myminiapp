/// Rus shashkasi (bitta telefonda ikki kishi).
///
/// Taxta: 64 katak, faqat qora kataklar ((qator+ustun) toq) ishlatiladi.
///   ''  bo'sh, 'w' oq dona, 'b' qora dona, 'W' oq damka, 'B' qora damka
/// Oq pastda (5–7 qatorlar), yuqoriga yuradi va birinchi boshlaydi.
///
/// Qoidalar:
///  - oddiy dona 1 katak oldinga yuradi, urishda orqaga ham uradi
///  - damka diagonal bo'ylab istalgan masofaga yuradi va uzoqdan uradi
///  - urish majburiy; urgandan keyin yana urish mumkin bo'lsa — davom etadi
///  - urilgan donalar yurish oxirida olinadi, bitta donani ikki marta urib bo'lmaydi
///  - dona oxirgi qatorga yetsa damka bo'ladi (urish paytida ham — urishni damka bo'lib davom ettiradi)
///  - damka urgandan keyin urishni davom ettira oladigan katakka tushishi shart
///  - raqibda dona yoki yurish qolmasa — yutqazadi
class CheckersMove {
  final int from;
  final int to;

  /// Urilgan dona katagi yoki -1.
  final int captured;

  const CheckersMove(this.from, this.to, [this.captured = -1]);

  bool get isCapture => captured >= 0;
}

class CheckersGame {
  late List<String> board;
  late String turn; // 'w' | 'b'
  String? winner; // 'w' | 'b' | 'draw'

  /// Zanjirli urish davom etayotgan dona (shu donadan boshqa yurish yo'q).
  int? chain;

  /// Shu yurishda urilgan, hali taxtadan olinmagan donalar.
  final captured = <int>{};

  /// Oxirgi yurish (ekranda belgilash uchun).
  int? lastFrom;
  int? lastTo;

  final score = {'w': 0, 'b': 0};
  int draws = 0;
  int round = 0;

  static const _dirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

  CheckersGame() {
    newRound();
  }

  bool get finished => winner != null;

  void newRound() {
    board = List.filled(64, '');
    for (var i = 0; i < 64; i++) {
      final r = i ~/ 8, c = i % 8;
      if ((r + c).isOdd) {
        if (r < 3) board[i] = 'b';
        if (r > 4) board[i] = 'w';
      }
    }
    turn = 'w';
    winner = null;
    chain = null;
    captured.clear();
    lastFrom = lastTo = null;
    round++;
  }

  static bool isKing(String p) => p == 'W' || p == 'B';
  static String colorOf(String p) => p.toLowerCase();
  static bool _inside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  bool _isEnemy(String piece, int at) {
    final other = board[at];
    return other.isNotEmpty && colorOf(other) != colorOf(piece);
  }

  /// [color] ning donalari soni.
  int count(String color) => board.where((p) => p.isNotEmpty && colorOf(p) == color).length;

  // ---------------------------------------------------------------- urish

  /// [from] dagi dona uchun urishlar.
  /// [mustContinue] — damka faqat urishni davom ettira oladigan kataklarga tushadi.
  List<CheckersMove> _capturesFrom(int from, {bool mustContinue = true}) {
    final piece = board[from];
    if (piece.isEmpty) return const [];
    final r = from ~/ 8, c = from % 8;
    final result = <CheckersMove>[];

    for (final (dr, dc) in _dirs) {
      if (!isKing(piece)) {
        final r1 = r + dr, c1 = c + dc, r2 = r + 2 * dr, c2 = c + 2 * dc;
        if (!_inside(r2, c2)) continue;
        final mid = r1 * 8 + c1, land = r2 * 8 + c2;
        if (_isEnemy(piece, mid) && !captured.contains(mid) && board[land].isEmpty) {
          result.add(CheckersMove(from, land, mid));
        }
        continue;
      }

      // Damka: bo'sh kataklardan o'tib, birinchi uchragan donani tekshiramiz
      var rr = r + dr, cc = c + dc;
      while (_inside(rr, cc) && board[rr * 8 + cc].isEmpty) {
        rr += dr;
        cc += dc;
      }
      if (!_inside(rr, cc)) continue;
      final mid = rr * 8 + cc;
      if (!_isEnemy(piece, mid) || captured.contains(mid)) continue;

      final landings = <int>[];
      rr += dr;
      cc += dc;
      while (_inside(rr, cc) && board[rr * 8 + cc].isEmpty) {
        landings.add(rr * 8 + cc);
        rr += dr;
        cc += dc;
      }
      if (landings.isEmpty) continue;

      var allowed = landings;
      if (mustContinue) {
        final continuing =
            landings.where((l) => _canContinueAfter(from, l, mid)).toList();
        if (continuing.isNotEmpty) allowed = continuing;
      }
      for (final l in allowed) {
        result.add(CheckersMove(from, l, mid));
      }
    }
    return result;
  }

  /// Damka [from] dan [mid] ni urib [landing] ga tushsa, yana ura oladimi.
  bool _canContinueAfter(int from, int landing, int mid) {
    final piece = board[from];
    board[landing] = piece;
    board[from] = '';
    captured.add(mid);
    final can = _capturesFrom(landing, mustContinue: false).isNotEmpty;
    captured.remove(mid);
    board[from] = piece;
    board[landing] = '';
    return can;
  }

  // ---------------------------------------------------------------- oddiy yurish

  List<CheckersMove> _quietMoves(int from) {
    final piece = board[from];
    final r = from ~/ 8, c = from % 8;
    final result = <CheckersMove>[];
    final forward = colorOf(piece) == 'w' ? -1 : 1;

    for (final (dr, dc) in _dirs) {
      if (!isKing(piece)) {
        if (dr != forward) continue;
        final rr = r + dr, cc = c + dc;
        if (_inside(rr, cc) && board[rr * 8 + cc].isEmpty) {
          result.add(CheckersMove(from, rr * 8 + cc));
        }
        continue;
      }
      var rr = r + dr, cc = c + dc;
      while (_inside(rr, cc) && board[rr * 8 + cc].isEmpty) {
        result.add(CheckersMove(from, rr * 8 + cc));
        rr += dr;
        cc += dc;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------- yurishlar

  /// Hozirgi o'yinchi uchun barcha ruxsat etilgan yurishlar.
  List<CheckersMove> legalMoves() {
    if (finished) return const [];
    if (chain != null) return _capturesFrom(chain!);

    final own = [
      for (var i = 0; i < 64; i++)
        if (board[i].isNotEmpty && colorOf(board[i]) == turn) i,
    ];
    final captures = [for (final i in own) ..._capturesFrom(i)];
    if (captures.isNotEmpty) return captures;
    return [for (final i in own) ..._quietMoves(i)];
  }

  /// Hozir urish majburiymi (ekranda ogohlantirish uchun).
  bool get mustCapture => legalMoves().any((m) => m.isCapture);

  /// Yurish. Qoidaga zid bo'lsa false.
  bool play(int from, int to) {
    final move = legalMoves()
        .where((m) => m.from == from && m.to == to)
        .firstOrNull;
    if (move == null) return false;

    final piece = board[from];
    board[to] = piece;
    board[from] = '';
    lastFrom = from;
    lastTo = to;

    // Oxirgi qatorga yetsa — damka
    final row = to ~/ 8;
    if (piece == 'w' && row == 0) board[to] = 'W';
    if (piece == 'b' && row == 7) board[to] = 'B';

    if (move.isCapture) {
      captured.add(move.captured);
      if (_capturesFrom(to).isNotEmpty) {
        chain = to; // urish davom etadi, navbat o'zgarmaydi
        return true;
      }
    }

    // Yurish tugadi: urilganlarni olib tashlaymiz, navbat almashadi
    for (final i in captured) {
      board[i] = '';
    }
    captured.clear();
    chain = null;

    final mover = turn;
    turn = turn == 'w' ? 'b' : 'w';
    if (count(turn) == 0 || legalMoves().isEmpty) {
      winner = mover;
      score[mover] = score[mover]! + 1;
    }
    return true;
  }

  /// Ikkala o'yinchi kelishib durang deb tugatadi.
  void agreeDraw() {
    if (finished) return;
    for (final i in captured) {
      board[i] = '';
    }
    captured.clear();
    chain = null;
    winner = 'draw';
    draws++;
  }
}
