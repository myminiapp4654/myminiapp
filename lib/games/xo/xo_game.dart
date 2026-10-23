/// X-O o'yini holati va qoidalari (bitta telefonda ikki kishi).
class XoGame {
  /// Taxta o'lchami -> g'alaba uchun nechtasi bir qatorda bo'lishi kerak.
  static const sizes = {3: 3, 10: 5};

  final int size;
  final int winLen;

  late List<String> board;
  late String turn;
  String? winner; // X | O | draw
  List<int> line = [];
  int? lastMove;

  /// Hisob raundlar davomida saqlanadi.
  final score = {'X': 0, 'O': 0};
  int draws = 0;
  int round = 0;

  /// Har raundda birinchi yuruvchi almashadi.
  String _starter = 'O';

  XoGame(this.size) : winLen = sizes[size]! {
    newRound();
  }

  bool get finished => winner != null;

  void newRound() {
    board = List.filled(size * size, '');
    _starter = _starter == 'X' ? 'O' : 'X';
    turn = _starter;
    winner = null;
    line = [];
    lastMove = null;
    round++;
  }

  /// Yurish. Mumkin bo'lmasa false.
  bool play(int index) {
    if (finished || index < 0 || index >= board.length) return false;
    if (board[index].isNotEmpty) return false;

    board[index] = turn;
    lastMove = index;

    final win = winningLine(board, size, winLen, index);
    if (win != null) {
      winner = turn;
      line = win;
      score[turn] = score[turn]! + 1;
    } else if (!board.contains('')) {
      winner = 'draw';
      draws++;
    } else {
      turn = turn == 'X' ? 'O' : 'X';
    }
    return true;
  }

  /// [index] ga qo'yilgan belgi g'alaba chizig'ini hosil qilgan bo'lsa,
  /// shu chiziqdagi kataklar, aks holda null.
  static List<int>? winningLine(
      List<String> board, int size, int winLen, int index) {
    final mark = board[index];
    if (mark.isEmpty) return null;
    final r0 = index ~/ size, c0 = index % size;

    for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      final cells = <int>[index];
      for (final sign in const [1, -1]) {
        var r = r0 + dr * sign, c = c0 + dc * sign;
        while (r >= 0 && r < size && c >= 0 && c < size &&
            board[r * size + c] == mark) {
          cells.add(r * size + c);
          r += dr * sign;
          c += dc * sign;
        }
      }
      if (cells.length >= winLen) return cells..sort();
    }
    return null;
  }
}
