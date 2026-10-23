import 'context.dart';

const kRooms = 'rooms';

String _create(Ctx c, Map<String, dynamic> p) {
  final code = c.db.newCode(kRooms);
  c.db.set('$kRooms/$code', {
    'code': code,
    'host': c.uid,
    'players': {
      c.uid: {'name': c.name},
    },
  });
  return code;
}

/// Xonaga kirish. Topilmasa yoki to'la bo'lsa false.
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

void _leave(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final path = '$kRooms/$code';
  final d = c.db.get(path);
  if (d == null) return;
  final players = d['players'] as Map<String, dynamic>;
  if (players.remove(c.uid) == null) return;
  if (players.isEmpty) {
    c.db.delete(path);
    return;
  }
  // Xo'jayin chiqsa, qolgan o'yinchi xo'jayin bo'ladi
  if (d['host'] == c.uid) d['host'] = players.keys.first;
  c.db.set(path, d);
}

Map<String, Handler> roomHandlers() => {
      'room.create': _create,
      'room.join': _join,
      'room.leave': (c, p) => _leave(c, p),
    };
