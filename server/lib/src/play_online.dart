import 'dart:math';

import 'context.dart';
import 'store.dart';

const kPlay = 'play';

/// Jonli o'yinlarda har bir o'yinchining tez yangilanadigan holati.
const kPlayState = 'pst';

/// Onlayn o'yinlar va ulardagi o'yinchilar soni.
const kPlayGames = {'chess': 2, 'checkers': 2, 'snake': 4};

/// Navbatma-navbat o'ynaladigan o'yinlar (yurishlar ketma-ketligi tekshiriladi).
const kTurnGames = {'chess', 'checkers'};

/// Onlayn xonalar (Shaxmat, Shashka, Neon Snake).
///
/// Xonani istalgan foydalanuvchi ochadi va do'stlarini havola bilan taklif qiladi.
/// Hujjat `play/<KOD>`:
///   game, host, state: lobby | playing | done, round, first (birinchi yuruvchi),
///   players: {uid: {name, order, ready}}, moves: [yurish matni, ...],
///   startAt, serverNow, left (chiqib ketgan o'yinchi)
///
/// Navbatli o'yinlarda server faqat navbat tartibini tekshiradi va yurishni
/// tarqatadi — qoidalarni har bir telefon o'zi tekshiradi (bir xil mantiq).
/// Jonli o'yinda (snake) har bir o'yinchi holatini `pst/<KOD>/<uid>` ga yozadi.
Map<String, Handler> playHandlers(Set<String> adminIds) => {
      'play.create': (c, p) => _create(c, p, adminIds),
      'play.join': _join,
      'play.ready': _ready,
      'play.move': _move,
      'play.state': _state,
      'play.end': _end,
      'play.again': _again,
      'play.leave': _leave,
    };

final _rnd = Random();

Object? _create(Ctx c, Map<String, dynamic> p, Set<String> adminIds) {
  final game = pStr(p, 'game', maxLen: 20);
  if (!kPlayGames.containsKey(game)) throw GameError("Noma'lum o'yin");
  final code = c.db.newCode(kPlay);
  c.db.set('$kPlay/$code', {
    'code': code,
    'game': game,
    'host': c.uid,
    'state': 'lobby',
    'round': 1,
    'players': {
      c.uid: {'name': c.name, 'order': 0, 'ready': false},
    },
    'moves': <String>[],
  });
  return {'code': code};
}

Map<String, dynamic> _room(Ctx c, Map<String, dynamic> p) =>
    c.db.require('$kPlay/${pCode(p)}', 'Xona topilmadi yoki yopilgan');

Map<String, dynamic> _players(Map<String, dynamic> d) => d['players'] as Map<String, dynamic>;

void _save(Ctx c, Map<String, dynamic> d) => c.db.set('$kPlay/${d['code']}', d);

void _requireMember(Ctx c, Map<String, dynamic> d) {
  if (!_players(d).containsKey(c.uid)) throw GameError('Siz bu xonada emassiz');
}

/// O'yinchilar kirgan tartibida.
List<String> _order(Map<String, dynamic> d) {
  final players = _players(d);
  return players.keys.toList()
    ..sort((a, b) => (players[a]['order'] as int).compareTo(players[b]['order'] as int));
}

Object? _join(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  final players = _players(d);
  if (players.containsKey(c.uid)) {
    (players[c.uid] as Map)['name'] = c.name;
  } else {
    if (d['state'] != 'lobby') throw GameError("O'yin allaqachon boshlangan");
    final max = kPlayGames[d['game']] ?? 2;
    if (players.length >= max) throw GameError("Xonada joy yo'q ($max kishi)");
    final order = players.values.fold<int>(0, (m, e) => max2(m, (e['order'] as int) + 1));
    players[c.uid] = {'name': c.name, 'order': order, 'ready': false};
  }
  _save(c, d);
  return {'code': d['code'], 'game': d['game']};
}

int max2(int a, int b) => a > b ? a : b;

Object? _ready(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  _requireMember(c, d);
  if (d['state'] != 'lobby') return null;
  (_players(d)[c.uid] as Map)['ready'] = p['ready'] == true;
  final players = _players(d).values.cast<Map>();
  if (players.length >= 2 && players.every((e) => e['ready'] == true)) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final order = _order(d);
    d['state'] = 'playing';
    d['moves'] = <String>[];
    d['left'] = null;
    d['serverNow'] = now;
    d['startAt'] = now + 3000;
    d['seed'] = _rnd.nextInt(1 << 30);
    // Navbatli o'yinda birinchi yuruvchi har raundda almashadi
    d['first'] = order[((d['round'] as int) - 1) % order.length];
  }
  _save(c, d);
  return null;
}

Object? _move(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  _requireMember(c, d);
  if (d['state'] != 'playing') throw GameError("O'yin hozir bormayapti");
  final m = pStr(p, 'm', maxLen: 200);
  final moves = (d['moves'] as List).cast<String>();
  if (kTurnGames.contains(d['game'])) {
    // Navbat: juft yurishlar — birinchi yuruvchi, toq — ikkinchisi
    final first = d['first'] as String;
    final mine = (moves.length.isEven) == (c.uid == first);
    if (!mine) throw GameError('Hozir sizning navbatingiz emas');
  }
  if (moves.length >= 2000) throw GameError("Yurishlar juda ko'p");
  d['moves'] = [...moves, m];
  _save(c, d);
  return {'n': moves.length + 1};
}

/// Jonli o'yin holati (snake): faqat shu o'yinchining holat hujjati yangilanadi.
Object? _state(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final s = p['s'];
  if (s is! Map) throw GameError("Noto'g'ri holat");
  c.db.set('$kPlayState/$code/${c.uid}', Map<String, dynamic>.from(s));
  return null;
}

Object? _end(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  _requireMember(c, d);
  if (d['state'] == 'playing') {
    d['state'] = 'done';
    _save(c, d);
  }
  return null;
}

Object? _again(Ctx c, Map<String, dynamic> p) {
  final d = _room(c, p);
  _requireMember(c, d);
  if (d['state'] == 'done') {
    d['state'] = 'lobby';
    d['round'] = (d['round'] as int) + 1;
    d['moves'] = <String>[];
    d['left'] = null;
    for (final e in _players(d).values.cast<Map>()) {
      e['ready'] = false;
    }
    _save(c, d);
  }
  return null;
}

Object? _leave(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final path = '$kPlay/$code';
  c.db.delete('$kPlayState/$code/${c.uid}');
  final d = c.db.get(path);
  if (d == null) return null;
  final players = _players(d);
  if (players.remove(c.uid) == null) return null;
  if (players.isEmpty) {
    c.db.delete(path);
    return null;
  }
  if (d['host'] == c.uid) d['host'] = players.keys.first;
  // O'yin paytida chiqsa: navbatli o'yinda raqib yutadi
  if (d['state'] == 'playing') {
    d['left'] = c.uid;
    if (kTurnGames.contains(d['game']) || players.length < 2) d['state'] = 'done';
  }
  _save(c, d);
  return null;
}
