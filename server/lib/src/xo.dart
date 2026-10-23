import 'context.dart';
import 'store.dart';

/// X-O qoidalari.
class XoRules {
  XoRules._();

  /// Taxta o'lchami -> g'alaba uchun nechtasi bir qatorda bo'lishi kerak.
  static const sizes = {3: 3, 10: 5};

  /// [index] ga qo'yilgan belgi g'alaba chizig'ini hosil qilgan bo'lsa,
  /// shu chiziqdagi kataklarni qaytaradi, aks holda null.
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

  /// Yangi raund. X har doim birinchi yuradi.
  static Map<String, dynamic> newGame({
    required int size,
    required String xUid,
    required String oUid,
    Map<String, dynamic>? score,
    int draws = 0,
    int round = 1,
  }) =>
      {
        'type': 'xo',
        'size': size,
        'winLen': sizes[size],
        'board': List.filled(size * size, ''),
        'x': xUid,
        'o': oUid,
        'turn': 'X',
        'status': 'playing', // playing | finished
        'winner': null, // X | O | draw
        'line': <int>[],
        'lastMove': null,
        'score': score ?? {xUid: 0, oUid: 0},
        'draws': draws,
        'round': round,
        'rematch': <String>[],
      };
}

Map<String, dynamic> _requireXo(Ctx c, String code) {
  final room = c.db.require('rooms/$code');
  if (!(room['players'] as Map).containsKey(c.uid)) {
    throw GameError('Siz bu xonada emassiz');
  }
  final game = room['game'];
  if (game is! Map || game['type'] != 'xo') throw GameError("O'yin topilmadi");
  return room;
}

void _move(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final room = _requireXo(c, code);
  final g = room['game'] as Map<String, dynamic>;
  if (g['status'] != 'playing') throw GameError("O'yin tugagan");

  final mark = g['x'] == c.uid ? 'X' : (g['o'] == c.uid ? 'O' : null);
  if (mark == null) throw GameError("Siz bu o'yinda emassiz");
  if (g['turn'] != mark) throw GameError('Hozir raqib navbati');

  final size = g['size'] as int;
  final index = pInt(p, 'index', min: 0, max: size * size - 1);
  final board = List<String>.from(g['board'] as List);
  if (board[index].isNotEmpty) throw GameError('Bu katak band');

  board[index] = mark;
  g['board'] = board;
  g['lastMove'] = index;

  final line =
      XoRules.winningLine(board, size, g['winLen'] as int, index);
  if (line != null) {
    g['status'] = 'finished';
    g['winner'] = mark;
    g['line'] = line;
    final score = g['score'] as Map<String, dynamic>;
    score[c.uid] = ((score[c.uid] as int?) ?? 0) + 1;
  } else if (!board.contains('')) {
    g['status'] = 'finished';
    g['winner'] = 'draw';
    g['draws'] = ((g['draws'] as int?) ?? 0) + 1;
  } else {
    g['turn'] = mark == 'X' ? 'O' : 'X';
  }
  c.db.set('rooms/$code', room);
}

/// "Yana o'ynash": ikkalasi ham bossa yangi raund, birinchi navbat almashadi.
void _rematch(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final room = _requireXo(c, code);
  final g = room['game'] as Map<String, dynamic>;
  if (g['status'] != 'finished') return;

  final votes = List<String>.from(g['rematch'] as List);
  if (!votes.contains(c.uid)) votes.add(c.uid);

  if (votes.contains(g['x']) && votes.contains(g['o'])) {
    room['game'] = XoRules.newGame(
      size: g['size'] as int,
      xUid: g['o'] as String,
      oUid: g['x'] as String,
      score: g['score'] as Map<String, dynamic>,
      draws: (g['draws'] as int?) ?? 0,
      round: ((g['round'] as int?) ?? 1) + 1,
    );
  } else {
    g['rematch'] = votes;
  }
  c.db.set('rooms/$code', room);
}

Map<String, Handler> xoHandlers() => {
      'xo.move': (c, p) => _move(c, p),
      'xo.rematch': (c, p) => _rematch(c, p),
    };
