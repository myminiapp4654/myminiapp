import '../context.dart';
import '../store.dart';
import 'games.dart';

const kRooms = 'rooms';

/// O'yin turi -> uni yaratish va unga qo'shilish.
final _games = <String, ({
  String Function(Ctx c, Map<String, dynamic> opts) create,
  bool Function(Ctx c, String code) join,
})>{
  'tictactoe': (
    create: (c, o) => createTicTacToe(c, (o['gridSize'] as int?) ?? 10),
    join: joinTicTacToe,
  ),
  'checkers': (create: (c, o) => createCheckers(c), join: joinCheckers),
  'quiz': (create: (c, o) => createQuiz(c, 10), join: joinQuiz),
  'hayoq': (create: (c, o) => createHaYoq(c, 5), join: joinHaYoq),
  'wordpuzzle': (create: (c, o) => createWordPuzzle(c), join: joinWordPuzzle),
  'scramble': (create: (c, o) => createScramble(c), join: joinScramble),
};

Map<String, dynamic> _requireMember(Ctx c, String code) {
  final d = c.db.require('$kRooms/$code');
  if (!(d['players'] as Map).containsKey(c.uid)) {
    throw GameError('Siz bu xonada emassiz');
  }
  return d;
}

String _create(Ctx c, Map<String, dynamic> p) {
  final code = c.db.newCode(kRooms);
  c.db.set('$kRooms/$code', {
    'code': code,
    'host': c.uid,
    'players': {
      c.uid: {'name': c.name},
    },
    'status': 'waiting',
    'gameInvite': null,
  });
  return code;
}

bool _join(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final path = '$kRooms/$code';
  final d = c.db.get(path);
  if (d == null) return false;
  final players = d['players'] as Map<String, dynamic>;
  if (players.containsKey(c.uid)) return true;
  if (players.length >= 2) return false;
  players[c.uid] = {'name': c.name};
  c.db.set(path, d);
  return true;
}

/// Xo'jayin o'yin tanlaydi: o'yin yaratiladi va taklif yuboriladi.
String _propose(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final game = pStr(p, 'game', maxLen: 20);
  final opts = p['options'] is Map
      ? Map<String, dynamic>.from(p['options'] as Map)
      : <String, dynamic>{};
  final d = _requireMember(c, code);
  if (d['host'] != c.uid) throw GameError("Faqat xo'jayin o'yin tanlaydi");
  if ((d['players'] as Map).length < 2) {
    throw GameError("Ikkinchi o'yinchi hali kirmadi");
  }
  final g = _games[game];
  if (g == null) throw GameError("Noma'lum o'yin");

  final gameCode = g.create(c, opts);
  c.db.set('$kRooms/$code', {
    ...d,
    'status': 'invited',
    'gameInvite': {
      'game': game,
      'gameCode': gameCode,
      'invitedBy': c.uid,
      'response': null,
    },
  });
  return gameCode;
}

/// Mehmon taklifni qabul qiladi: o'yinga qo'shiladi, ikkalasi o'yinga o'tadi.
void _accept(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requireMember(c, code);
  final invite = d['gameInvite'] as Map<String, dynamic>?;
  if (invite == null || invite['response'] != null) return;
  if (invite['invitedBy'] == c.uid) return;

  final g = _games[invite['game']];
  if (g == null || !g.join(c, invite['gameCode'] as String)) {
    throw GameError("O'yinga qo'shilib bo'lmadi");
  }
  invite['response'] = 'accepted';
  d['status'] = 'playing';
  c.db.set('$kRooms/$code', d);
}

void _reject(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requireMember(c, code);
  final invite = d['gameInvite'] as Map<String, dynamic>?;
  if (invite != null && invite['response'] == null) {
    // Yaratilgan, lekin boshlanmagan o'yinni ham tozalaymiz
    final collection = switch (invite['game']) {
      'tictactoe' => kTicTacToe,
      'checkers' => kCheckers,
      'quiz' => kQuiz,
      'hayoq' => kHaYoq,
      'wordpuzzle' => kWordPuzzle,
      'scramble' => kScramble,
      _ => null,
    };
    if (collection != null) {
      c.db.delete('$collection/${invite['gameCode']}');
    }
  }
  c.db.set('$kRooms/$code', {...d, 'gameInvite': null, 'status': 'waiting'});
}

void _reset(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = c.db.get('$kRooms/$code');
  if (d == null || !(d['players'] as Map).containsKey(c.uid)) return;
  c.db.set('$kRooms/$code', {...d, 'gameInvite': null, 'status': 'waiting'});
}

void _leave(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final path = '$kRooms/$code';
  final d = c.db.get(path);
  if (d == null) return;
  final players = d['players'] as Map<String, dynamic>;
  if (!players.containsKey(c.uid)) return;
  players.remove(c.uid);
  if (players.isEmpty) {
    c.db.delete(path);
    return;
  }
  // Xo'jayin chiqsa, qolgan o'yinchi xo'jayin bo'ladi
  if (d['host'] == c.uid) d['host'] = players.keys.first;
  d['gameInvite'] = null;
  d['status'] = 'waiting';
  c.db.set(path, d);
}

Map<String, Handler> roomHandlers() => {
      'room.create': _create,
      'room.join': _join,
      'room.propose': _propose,
      'room.accept': (c, p) => _accept(c, p),
      'room.reject': (c, p) => _reject(c, p),
      'room.reset': (c, p) => _reset(c, p),
      'room.leave': (c, p) => _leave(c, p),
    };
