import 'context.dart';
import 'store.dart';

const kStack = 'stack';
const kStackMaxPlayers = 4;

/// Boshlanishdan oldingi sanoq.
const kStackCountdownMs = 3000;

/// Onlayn Stack musobaqasi.
///
/// Xonani faqat admin ochadi, boshqalar taklif havolasi bilan kiradi.
/// Hujjat `stack/<KOD>`:
///   host, state: lobby | playing | done, startAt, serverNow,
///   players: {uid: {name, order, ready, over, moves: [siljish, ...]}}
///
/// O'yin har bir telefonda hisoblanadi; server faqat har bir qo'yilgan
/// blokning siljishini ([moves]) tarqatadi — Stack'da tasodif yo'q, shuning
/// uchun shu siljishlar bilan har kimning minorasi boshqalarda aynan tiklanadi.
Map<String, Handler> stackHandlers(Set<String> adminIds) => {
      'stack.create': (c, p) => _create(c, adminIds),
      'stack.join': _join,
      'stack.ready': _ready,
      'stack.place': _place,
      'stack.over': _over,
      'stack.again': _again,
      'stack.leave': _leave,
    };

bool _isAdmin(Ctx c, Set<String> adminIds) =>
    c.uid.startsWith('tg') && adminIds.contains(c.uid.substring(2));

Map<String, dynamic> _player(Ctx c, int order) =>
    {'name': c.name, 'order': order, 'ready': false, 'over': false, 'moves': <double>[]};

Object? _create(Ctx c, Set<String> adminIds) {
  if (!_isAdmin(c, adminIds)) throw GameError('Faqat admin xona ocha oladi');
  final code = c.db.newCode(kStack);
  c.db.set('$kStack/$code', {
    'code': code,
    'host': c.uid,
    'state': 'lobby',
    'players': {c.uid: _player(c, 0)},
  });
  return {'code': code};
}

Map<String, dynamic> _room(Ctx c, Map<String, dynamic> p) =>
    c.db.require('$kStack/${pCode(p)}', 'Xona topilmadi yoki yopilgan');

Map<String, dynamic> _players(Map<String, dynamic> d) => d['players'] as Map<String, dynamic>;

Map<String, dynamic> _me(Ctx c, Map<String, dynamic> d) {
  final me = _players(d)[c.uid];
  if (me == null) throw GameError('Siz bu xonada emassiz');
  return me as Map<String, dynamic>;
}

void _save(Ctx c, Map<String, dynamic> d) => c.db.set('$kStack/${d['code']}', d);

Object? _join(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  final players = _players(d);
  if (players.containsKey(c.uid)) {
    // Qayta kirdi — ismini yangilaymiz
    (players[c.uid] as Map)['name'] = c.name;
  } else {
    if (d['state'] != 'lobby') throw GameError("O'yin allaqachon boshlangan");
    if (players.length >= kStackMaxPlayers) throw GameError("Xonada joy yo'q (4 kishi)");
    final order = players.values.fold<int>(0, (m, e) => (e['order'] as int) >= m ? (e['order'] as int) + 1 : m);
    players[c.uid] = _player(c, order);
  }
  _save(c, d);
  return {'code': d['code']};
}

Object? _ready(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  if (d['state'] != 'lobby') return null;
  _me(c, d)['ready'] = p['ready'] == true;
  final players = _players(d).values.cast<Map<String, dynamic>>();
  // Hamma tayyor (kamida 2 kishi) — 3 soniyadan keyin boshlanadi
  if (players.length >= 2 && players.every((e) => e['ready'] == true)) {
    final now = DateTime.now().millisecondsSinceEpoch;
    d['state'] = 'playing';
    d['serverNow'] = now;
    d['startAt'] = now + kStackCountdownMs;
    for (final e in players) {
      e['moves'] = <double>[];
      e['over'] = false;
    }
  }
  _save(c, d);
  return null;
}

Object? _place(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  if (d['state'] != 'playing') return null;
  final me = _me(c, d);
  final offset = p['offset'];
  if (offset is! num || offset.abs() > 100) throw GameError("Noto'g'ri yurish");
  final moves = me['moves'] as List;
  if (moves.length >= 1000 || me['over'] == true) return null;
  moves.add(offset.toDouble());
  _save(c, d);
  return null;
}

void _checkDone(Map<String, dynamic> d) {
  final players = _players(d).values.cast<Map<String, dynamic>>();
  if (d['state'] == 'playing' && players.every((e) => e['over'] == true)) d['state'] = 'done';
}

Object? _over(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  if (d['state'] != 'playing') return null;
  _me(c, d)['over'] = true;
  _checkDone(d);
  _save(c, d);
  return null;
}

/// Yana o'ynash: xona lobbiga qaytadi, hamma qaytadan "Tayyorman" bosadi.
Object? _again(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  _me(c, d);
  if (d['state'] == 'done') {
    d['state'] = 'lobby';
    for (final e in _players(d).values.cast<Map<String, dynamic>>()) {
      e['ready'] = false;
      e['over'] = false;
      e['moves'] = <double>[];
    }
    _save(c, d);
  }
  return null;
}

Object? _leave(Ctx c, Map<String, dynamic> p) {
  final path = '$kStack/${pCode(p)}';
  final d = c.db.get(path);
  if (d == null) return null;
  final players = _players(d);
  if (players.remove(c.uid) == null) return null;
  if (players.isEmpty) {
    c.db.delete(path);
    return null;
  }
  if (d['host'] == c.uid) d['host'] = players.keys.first;
  _checkDone(d);
  _save(c, d);
  return null;
}
