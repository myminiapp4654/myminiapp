import 'dart:math';

/// Shaxmat: to'liq qoidalar.
///
/// Taxta: 64 katak, 0 = a8 (yuqori chap), 63 = h1 (pastki o'ng).
/// Donalar: oq — 'P N B R Q K', qora — 'p n b r q k', bo'sh — ''.
/// Qoidalar: rokirovka, en passant, piyodaning aylanishi, shax/mat/pat,
/// durang: 50 yurish, uch marta takrorlanish, matga yetarli dona yo'q.
class ChessMove {
  final int from;
  final int to;

  /// Aylanish: 'q', 'r', 'b', 'n' (kichik harf) yoki null.
  final String? promo;
  final bool castle;
  final bool enPassant;

  const ChessMove(this.from, this.to,
      {this.promo, this.castle = false, this.enPassant = false});

  @override
  bool operator ==(Object other) =>
      other is ChessMove &&
      other.from == from &&
      other.to == to &&
      other.promo == promo;

  @override
  int get hashCode => Object.hash(from, to, promo);

  @override
  String toString() => '${squareName(from)}${squareName(to)}${promo ?? ''}';
}

/// Katak nomi: 0 -> a8, 63 -> h1.
String squareName(int sq) => '${'abcdefgh'[sq % 8]}${8 - sq ~/ 8}';

int squareOf(String name) =>
    (8 - int.parse(name[1])) * 8 + 'abcdefgh'.indexOf(name[0]);

bool isWhitePiece(String p) => p.isNotEmpty && p == p.toUpperCase();

class _Undo {
  final ChessMove move;
  final String moved;
  final String captured;
  final int capturedAt;
  final String castling;
  final int? ep;
  final int halfmove;

  _Undo(this.move, this.moved, this.captured, this.capturedAt, this.castling,
      this.ep, this.halfmove);
}

enum ChessResult { playing, checkmate, stalemate, fiftyMoves, repetition, material }

class ChessGame {
  late List<String> board;
  String turn = 'w';

  /// Rokirovka huquqlari: 'KQkq' qismi.
  String castling = 'KQkq';
  int? ep;
  int halfmove = 0;
  int fullmove = 1;

  final _undo = <_Undo>[];
  final _keys = <String>[];

  /// Yurishlar yozuvi (SAN): e4, Nf3, O-O, exd5, e8=Q+ ...
  final san = <String>[];

  static const startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  ChessGame([String fen = startFen]) {
    loadFen(fen);
  }

  void loadFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    board = [];
    for (final ch in parts[0].split('')) {
      if (ch == '/') continue;
      final n = int.tryParse(ch);
      if (n != null) {
        board.addAll(List.filled(n, ''));
      } else {
        board.add(ch);
      }
    }
    turn = parts.length > 1 ? parts[1] : 'w';
    castling = parts.length > 2 && parts[2] != '-' ? parts[2] : '';
    ep = parts.length > 3 && parts[3] != '-' ? squareOf(parts[3]) : null;
    halfmove = parts.length > 4 ? int.parse(parts[4]) : 0;
    fullmove = parts.length > 5 ? int.parse(parts[5]) : 1;
    _undo.clear();
    _keys
      ..clear()
      ..add(_key());
    san.clear();
  }

  String _key() => '${board.join(',')}|$turn|$castling|${ep ?? '-'}';

  bool _mine(String p, String color) =>
      p.isNotEmpty && (color == 'w') == isWhitePiece(p);

  static bool _in(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  static const _knight = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)];
  static const _king = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)];
  static const _rook = [(-1, 0), (1, 0), (0, -1), (0, 1)];
  static const _bishop = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

  // ---------------------------------------------------------------- hujum

  /// [sq] katakni [by] rangidagi donalar uradimi.
  bool isAttacked(int sq, String by) {
    final r = sq ~/ 8, c = sq % 8;
    final white = by == 'w';

    // Piyoda: oq piyoda yuqoriga uradi, ya'ni katak ostidan
    final pr = white ? r + 1 : r - 1;
    for (final dc in const [-1, 1]) {
      if (_in(pr, c + dc) && board[pr * 8 + c + dc] == (white ? 'P' : 'p')) {
        return true;
      }
    }
    for (final (dr, dc) in _knight) {
      if (_in(r + dr, c + dc) &&
          board[(r + dr) * 8 + c + dc] == (white ? 'N' : 'n')) {
        return true;
      }
    }
    for (final (dr, dc) in _king) {
      if (_in(r + dr, c + dc) &&
          board[(r + dr) * 8 + c + dc] == (white ? 'K' : 'k')) {
        return true;
      }
    }
    bool ray(List<(int, int)> dirs, String a, String b) {
      for (final (dr, dc) in dirs) {
        var rr = r + dr, cc = c + dc;
        while (_in(rr, cc)) {
          final p = board[rr * 8 + cc];
          if (p.isNotEmpty) {
            if (p == a || p == b) return true;
            break;
          }
          rr += dr;
          cc += dc;
        }
      }
      return false;
    }

    return ray(_rook, white ? 'R' : 'r', white ? 'Q' : 'q') ||
        ray(_bishop, white ? 'B' : 'b', white ? 'Q' : 'q');
  }

  int kingSquare(String color) => board.indexOf(color == 'w' ? 'K' : 'k');

  bool inCheck([String? color]) {
    final c = color ?? turn;
    final k = kingSquare(c);
    return k >= 0 && isAttacked(k, c == 'w' ? 'b' : 'w');
  }

  // ---------------------------------------------------------------- yurishlar

  List<ChessMove> _pseudo() {
    final moves = <ChessMove>[];
    final us = turn, them = turn == 'w' ? 'b' : 'w';
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (!_mine(p, us)) continue;
      final r = sq ~/ 8, c = sq % 8;
      switch (p.toLowerCase()) {
        case 'p':
          final dir = us == 'w' ? -1 : 1;
          final startRow = us == 'w' ? 6 : 1;
          final promoRow = us == 'w' ? 0 : 7;
          void add(int to) {
            if (to ~/ 8 == promoRow) {
              for (final pr in const ['q', 'r', 'b', 'n']) {
                moves.add(ChessMove(sq, to, promo: pr));
              }
            } else {
              moves.add(ChessMove(sq, to));
            }
          }

          final one = (r + dir) * 8 + c;
          if (_in(r + dir, c) && board[one].isEmpty) {
            add(one);
            final two = (r + 2 * dir) * 8 + c;
            if (r == startRow && board[two].isEmpty) moves.add(ChessMove(sq, two));
          }
          for (final dc in const [-1, 1]) {
            if (!_in(r + dir, c + dc)) continue;
            final to = (r + dir) * 8 + c + dc;
            if (_mine(board[to], them)) add(to);
            if (to == ep) moves.add(ChessMove(sq, to, enPassant: true));
          }
        case 'n':
          for (final (dr, dc) in _knight) {
            if (!_in(r + dr, c + dc)) continue;
            final to = (r + dr) * 8 + c + dc;
            if (!_mine(board[to], us)) moves.add(ChessMove(sq, to));
          }
        case 'k':
          for (final (dr, dc) in _king) {
            if (!_in(r + dr, c + dc)) continue;
            final to = (r + dr) * 8 + c + dc;
            if (!_mine(board[to], us)) moves.add(ChessMove(sq, to));
          }
          _castles(moves, sq);
        default:
          final dirs = switch (p.toLowerCase()) {
            'r' => _rook,
            'b' => _bishop,
            _ => [..._rook, ..._bishop],
          };
          for (final (dr, dc) in dirs) {
            var rr = r + dr, cc = c + dc;
            while (_in(rr, cc)) {
              final to = rr * 8 + cc;
              if (_mine(board[to], us)) break;
              moves.add(ChessMove(sq, to));
              if (board[to].isNotEmpty) break;
              rr += dr;
              cc += dc;
            }
          }
      }
    }
    return moves;
  }

  void _castles(List<ChessMove> moves, int kingSq) {
    final white = turn == 'w';
    final them = white ? 'b' : 'w';
    final home = white ? 60 : 4;
    if (kingSq != home || isAttacked(home, them)) return;
    bool empty(List<int> s) => s.every((i) => board[i].isEmpty);
    bool safe(List<int> s) => s.every((i) => !isAttacked(i, them));

    if (castling.contains(white ? 'K' : 'k') &&
        board[home + 3] == (white ? 'R' : 'r') &&
        empty([home + 1, home + 2]) &&
        safe([home + 1, home + 2])) {
      moves.add(ChessMove(home, home + 2, castle: true));
    }
    if (castling.contains(white ? 'Q' : 'q') &&
        board[home - 4] == (white ? 'R' : 'r') &&
        empty([home - 1, home - 2, home - 3]) &&
        safe([home - 1, home - 2])) {
      moves.add(ChessMove(home, home - 2, castle: true));
    }
  }

  /// Qoidaga mos yurishlar (shohni shax ostida qoldirmaydigan).
  List<ChessMove> legalMoves() {
    final us = turn;
    final result = <ChessMove>[];
    for (final m in _pseudo()) {
      _make(m);
      if (!inCheck(us)) result.add(m);
      _unmake();
    }
    return result;
  }

  void _make(ChessMove m) {
    final piece = board[m.from];
    var capturedAt = m.to;
    if (m.enPassant) capturedAt = (m.from ~/ 8) * 8 + m.to % 8;
    final captured = board[capturedAt];
    _undo.add(_Undo(m, piece, captured, capturedAt, castling, ep, halfmove));

    board[capturedAt] = '';
    board[m.to] = m.promo == null
        ? piece
        : (turn == 'w' ? m.promo!.toUpperCase() : m.promo!);
    board[m.from] = '';

    if (m.castle) {
      final kingSide = m.to > m.from;
      final rookFrom = kingSide ? m.from + 3 : m.from - 4;
      final rookTo = kingSide ? m.from + 1 : m.from - 1;
      board[rookTo] = board[rookFrom];
      board[rookFrom] = '';
    }

    // Rokirovka huquqlari: shoh yoki rux qo'zg'alsa / rux urilsa
    var rights = castling;
    void drop(String s) => rights = rights.replaceAll(s, '');
    if (piece == 'K') drop('KQ');
    if (piece == 'k') drop('kq');
    for (final sq in [m.from, m.to]) {
      if (sq == 63) drop('K');
      if (sq == 56) drop('Q');
      if (sq == 7) drop('k');
      if (sq == 0) drop('q');
    }
    castling = rights;

    ep = piece.toLowerCase() == 'p' && (m.to - m.from).abs() == 16
        ? (m.from + m.to) ~/ 2
        : null;
    halfmove = piece.toLowerCase() == 'p' || captured.isNotEmpty ? 0 : halfmove + 1;
    if (turn == 'b') fullmove++;
    turn = turn == 'w' ? 'b' : 'w';
  }

  void _unmake() {
    final u = _undo.removeLast();
    final m = u.move;
    turn = turn == 'w' ? 'b' : 'w';
    if (turn == 'b') fullmove--;
    board[m.from] = u.moved;
    board[m.to] = '';
    board[u.capturedAt] = u.captured;
    if (m.castle) {
      final kingSide = m.to > m.from;
      final rookFrom = kingSide ? m.from + 3 : m.from - 4;
      final rookTo = kingSide ? m.from + 1 : m.from - 1;
      board[rookFrom] = board[rookTo];
      board[rookTo] = '';
    }
    castling = u.castling;
    ep = u.ep;
    halfmove = u.halfmove;
  }

  // ---------------------------------------------------------------- o'yin

  /// Yurish qilish (qoidaga zid bo'lsa false). SAN yozuvi ham qo'shiladi.
  bool play(ChessMove move) {
    final legal = legalMoves();
    final m = legal.where((x) => x == move).firstOrNull;
    if (m == null) return false;
    final text = _san(m, legal);
    _make(m);
    _keys.add(_key());
    final r = result;
    san.add(text + (r == ChessResult.checkmate ? '#' : (inCheck() ? '+' : '')));
    return true;
  }

  /// "e2e4", "e7e8q" ko'rinishidagi yurish.
  bool playUci(String uci) => play(ChessMove(squareOf(uci.substring(0, 2)),
      squareOf(uci.substring(2, 4)),
      promo: uci.length > 4 ? uci[4] : null));

  bool get canUndo => _undo.isNotEmpty;

  void undo() {
    if (_undo.isEmpty) return;
    _unmake();
    _keys.removeLast();
    san.removeLast();
  }

  ChessMove? get lastMove => _undo.isEmpty ? null : _undo.last.move;

  ChessResult get result {
    if (legalMoves().isEmpty) {
      return inCheck() ? ChessResult.checkmate : ChessResult.stalemate;
    }
    if (halfmove >= 100) return ChessResult.fiftyMoves;
    final key = _keys.last;
    if (_keys.where((k) => k == key).length >= 3) return ChessResult.repetition;
    if (_insufficient()) return ChessResult.material;
    return ChessResult.playing;
  }

  bool _insufficient() {
    final pieces = [for (final p in board) if (p.isNotEmpty && p.toLowerCase() != 'k') p];
    if (pieces.isEmpty) return true;
    if (pieces.length == 1 && 'nNbB'.contains(pieces.single)) return true;
    return false;
  }

  /// Urilgan donalar (taxtadan yo'qolganlar).
  List<String> capturedPieces(String color) {
    const full = {'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1};
    final out = <String>[];
    full.forEach((p, n) {
      final piece = color == 'w' ? p.toUpperCase() : p;
      final have = board.where((x) => x == piece).length;
      for (var k = have; k < n; k++) {
        out.add(piece);
      }
    });
    return out;
  }

  String _san(ChessMove m, List<ChessMove> legal) {
    if (m.castle) return m.to > m.from ? 'O-O' : 'O-O-O';
    final piece = board[m.from];
    final type = piece.toUpperCase();
    final capture = board[m.to].isNotEmpty || m.enPassant;
    final to = squareName(m.to);
    if (type == 'P') {
      final s = capture ? '${squareName(m.from)[0]}x$to' : to;
      return m.promo == null ? s : '$s=${m.promo!.toUpperCase()}';
    }
    final rivals = legal
        .where((x) => x.to == m.to && x.from != m.from && board[x.from] == piece)
        .toList();
    var dis = '';
    if (rivals.isNotEmpty) {
      final f = squareName(m.from)[0], r = squareName(m.from)[1];
      if (rivals.every((x) => squareName(x.from)[0] != f)) {
        dis = f;
      } else if (rivals.every((x) => squareName(x.from)[1] != r)) {
        dis = r;
      } else {
        dis = f + r;
      }
    }
    return '$type$dis${capture ? 'x' : ''}$to';
  }

  /// Berilgan chuqurlikdagi yurishlar soni (generatorni tekshirish uchun).
  int perft(int depth) {
    if (depth == 0) return 1;
    final moves = legalMoves();
    if (depth == 1) return moves.length;
    var n = 0;
    for (final m in moves) {
      _make(m);
      n += perft(depth - 1);
      _unmake();
    }
    return n;
  }

  // ---------------------------------------------------------------- kompyuter

  static const _value = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};

  /// Oq tomonidan baho (santipeshkada).
  int evaluate() {
    var score = 0;
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p.isEmpty) continue;
      final t = p.toLowerCase();
      final white = isWhitePiece(p);
      final r = sq ~/ 8, c = sq % 8;
      var v = _value[t]!;
      // Markazga yaqinlik (ot, fil, piyoda)
      final center = 7 - ((3.5 - r).abs() + (3.5 - c).abs()).round();
      if (t == 'n' || t == 'b') v += center * 4;
      if (t == 'p') {
        v += (white ? 6 - r : r - 1) * 6; // oldinga borgan piyoda
        if (c >= 2 && c <= 5) v += center * 2;
      }
      if (t == 'k' && fullmove < 40) v -= center * 4; // shoh xavfsiz burchakda
      score += white ? v : -v;
    }
    return score;
  }

  int _order(ChessMove m) {
    final victim = board[m.enPassant ? (m.from ~/ 8) * 8 + m.to % 8 : m.to];
    var s = 0;
    if (victim.isNotEmpty) {
      s += 10 * _value[victim.toLowerCase()]! - _value[board[m.from].toLowerCase()]! ~/ 10;
    }
    if (m.promo == 'q') s += 8000;
    return s;
  }

  int _quiesce(int alpha, int beta, int depth) {
    final stand = (turn == 'w' ? 1 : -1) * evaluate();
    if (depth == 0) return stand;
    if (stand >= beta) return beta;
    if (stand > alpha) alpha = stand;
    final captures = legalMoves()
        .where((m) => board[m.to].isNotEmpty || m.enPassant || m.promo != null)
        .toList()
      ..sort((a, b) => _order(b) - _order(a));
    for (final m in captures) {
      _make(m);
      final s = -_quiesce(-beta, -alpha, depth - 1);
      _unmake();
      if (s >= beta) return beta;
      if (s > alpha) alpha = s;
    }
    return alpha;
  }

  int _search(int depth, int alpha, int beta, int ply) {
    final moves = legalMoves();
    if (moves.isEmpty) return inCheck() ? -100000 + ply : 0;
    if (halfmove >= 100) return 0;
    if (depth == 0) return _quiesce(alpha, beta, 4);
    moves.sort((a, b) => _order(b) - _order(a));
    for (final m in moves) {
      _make(m);
      final s = -_search(depth - 1, -beta, -alpha, ply + 1);
      _unmake();
      if (s >= beta) return beta;
      if (s > alpha) alpha = s;
    }
    return alpha;
  }

  /// Kompyuter yurishi. [level]: 1 oson, 2 o'rta, 3 qiyin.
  ChessMove? bestMove(int level, [Random? random]) {
    final rnd = random ?? Random();
    final moves = legalMoves();
    if (moves.isEmpty) return null;
    moves.sort((a, b) => _order(b) - _order(a));
    final depth = level.clamp(1, 3);
    final scored = <(ChessMove, int)>[];
    var alpha = -1000000;
    for (final m in moves) {
      _make(m);
      // Osonda aniq qidiruv shart emas — taxminiy baholar yetarli
      final s = -_search(depth - 1, -1000000, level == 1 ? 1000000 : -alpha, 1);
      _unmake();
      scored.add((m, s));
      if (s > alpha) alpha = s;
    }
    scored.sort((a, b) => b.$2 - a.$2);
    if (level == 1) {
      // Oson: eng yaxshilariga yaqin bo'lganlardan tasodifiy
      final ok = scored.where((x) => x.$2 >= scored.first.$2 - 90).toList();
      return ok[rnd.nextInt(ok.length)].$1;
    }
    return scored.first.$1;
  }
}
