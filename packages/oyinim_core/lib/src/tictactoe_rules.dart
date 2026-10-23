class TicTacToeRules {
  TicTacToeRules._();

  /// [index] katakni o'z ichiga olgan barcha yangi 5 talik qatorlar.
  static List<List<int>> findNewLines(
      List<String> board, int gridSize, int index, String symbol) {
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final found = <List<int>>[];

    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (final dir in dirs) {
      final dr = dir[0];
      final dc = dir[1];
      for (int start = -4; start <= 0; start++) {
        final cells = <int>[];
        var valid = true;
        for (int i = 0; i < 5; i++) {
          final r = row + (start + i) * dr;
          final c = col + (start + i) * dc;
          if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) {
            valid = false;
            break;
          }
          final idx = r * gridSize + c;
          if (board[idx] != symbol) {
            valid = false;
            break;
          }
          cells.add(idx);
        }
        if (valid && cells.length == 5) found.add(cells);
      }
    }
    return found;
  }
}
