// Shashka qoidalari (rus shashkasi, soddalashtirilgan):
// - Taxta: 64 katak. '' bo'sh, 'w' oq, 'b' qora, 'W' oq damka, 'B' qora damka
// - Faqat qora kataklar: (row+col)%2 == 1
// - Oq (player1) 5-7 qatorlarda, yuqoriga yuradi; qora (player2) 0-2 qatorlarda, pastga
// - Oddiy yurish faqat oldinga, urish to'rt tomonga; urish majburiy; zanjirli urish

class CheckersRules {
  CheckersRules._();

  static const _diagonals = [
    [-1, -1], [-1, 1], [1, -1], [1, 1],
  ];

  static List<String> initialBoard() {
    final board = List.filled(64, '');
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) board[row * 8 + col] = 'b';
      }
    }
    for (int row = 5; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) board[row * 8 + col] = 'w';
      }
    }
    return board;
  }

  static bool _isWhite(String p) => p == 'w' || p == 'W';
  static bool _isKing(String p) => p == 'W' || p == 'B';

  static bool _isEnemy(String piece, String other) {
    if (other.isEmpty) return false;
    return _isWhite(piece) ? !_isWhite(other) : _isWhite(other);
  }

  /// [from] dagi dona uchun mumkin bo'lgan yurishlar.
  /// Har biri: {'to': katak, 'captured': urilgan katak yoki -1}
  static List<Map<String, int>> validMoves(
      List<String> board, int from, int chainJump) {
    if (from < 0 || from >= 64 || board[from].isEmpty) return [];
    if (chainJump >= 0 && chainJump != from) return [];

    final piece = board[from];
    final row = from ~/ 8;
    final col = from % 8;
    final isWhite = _isWhite(piece);
    final isKing = _isKing(piece);

    final jumps = <Map<String, int>>[];
    for (final d in _diagonals) {
      final nr = row + d[0], nc = col + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      final ni = nr * 8 + nc;
      if (!_isEnemy(piece, board[ni])) continue;
      final jr = nr + d[0], jc = nc + d[1];
      if (jr < 0 || jr >= 8 || jc < 0 || jc >= 8) continue;
      final ji = jr * 8 + jc;
      if (board[ji].isEmpty) jumps.add({'to': ji, 'captured': ni});
    }

    if (jumps.isNotEmpty) return jumps;
    if (chainJump >= 0) return [];

    // Boshqa dona urishi mumkin bo'lsa — oddiy yurish taqiqlangan
    if (anyJump(board, isWhite ? 'w' : 'b')) return [];

    final moves = <Map<String, int>>[];
    final dirs = <List<int>>[
      if (isWhite || isKing) ...[[-1, -1], [-1, 1]],
      if (!isWhite || isKing) ...[[1, -1], [1, 1]],
    ];
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      final ni = nr * 8 + nc;
      if (board[ni].isEmpty) moves.add({'to': ni, 'captured': -1});
    }
    return moves;
  }

  /// [color] ('w' yoki 'b') rangidagi biror dona urish qila oladimi.
  static bool anyJump(List<String> board, String color) {
    for (int i = 0; i < 64; i++) {
      if (board[i].isEmpty || board[i].toLowerCase() != color) continue;
      if (jumpsFor(board, i).isNotEmpty) return true;
    }
    return false;
  }

  /// [from] dagi dona urib tusha oladigan kataklar.
  static List<int> jumpsFor(List<String> board, int from) {
    final piece = board[from];
    if (piece.isEmpty) return [];
    final row = from ~/ 8, col = from % 8;
    final result = <int>[];
    for (final d in _diagonals) {
      final nr = row + d[0], nc = col + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      if (!_isEnemy(piece, board[nr * 8 + nc])) continue;
      final jr = nr + d[0], jc = nc + d[1];
      if (jr >= 0 && jr < 8 && jc >= 0 && jc < 8 &&
          board[jr * 8 + jc].isEmpty) {
        result.add(jr * 8 + jc);
      }
    }
    return result;
  }

  /// [color] rangida umuman yurish bormi.
  static bool hasAnyMove(List<String> board, String color) {
    for (int i = 0; i < 64; i++) {
      if (board[i].isNotEmpty &&
          board[i].toLowerCase() == color &&
          validMoves(board, i, -1).isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
