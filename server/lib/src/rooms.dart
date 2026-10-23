import 'context.dart';
import 'store.dart';
import 'xo.dart';

const kRooms = 'rooms';

/// Xonadagi o'yin turlari va ularni boshlash.
/// Taklif qilgan o'yinchi birinchi yuradi.
final _games = <String, Map<String, dynamic> Function(
    Map<String, dynamic> options, String inviter, String accepter)>{
  'xo': (o, inviter, accepter) => XoRules.newGame(
      size: o['size'] as int, xUid: inviter, oUid: accepter),
};

/// Taklif parametrlarini tekshiradi va tozalaydi.
Map<String, dynamic> _validOptions(String game, Map<String, dynamic> options) {
  switch (game) {
    case 'xo':
      final size = options['size'];
      if (size is! int || !XoRules.sizes.containsKey(size)) {
        throw GameError("Noto'g'ri taxta o'lchami");
      }
      return {'size': size};
    default:
      throw GameError("Noma'lum o'yin");
  }
}

Map<String, dynamic> _requireMember(Ctx c, String code) {
  final d = c.db.require('$kRooms/$code');
  if (!(d['players'] as Map).containsKey(c.uid)) {
    throw GameError('Siz bu xonada emassiz');
  }
  return d;
}

void _event(Map<String, dynamic> room, String type, Ctx c) {
  room['event'] = {
    'type': type,
    'uid': c.uid,
    'name': c.name,
    'at': DateTime.now().millisecondsSinceEpoch,
  };
}

/// Foydalanuvchini xonadan chiqaradi (xona bo'shasa o'chiriladi).
void _removeFrom(Ctx c, String path) {
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
  d['game'] = null;
  d['invite'] = null;
  _event(d, 'left', c);
  c.db.set(path, d);
}

/// Bir odam bir vaqtda faqat bitta xonada bo'ladi.
void _leaveOtherRooms(Ctx c, [String? keep]) {
  for (final path in c.db.pathsIn(kRooms)) {
    if (path != '$kRooms/$keep') _removeFrom(c, path);
  }
}

String _create(Ctx c, Map<String, dynamic> p) {
  _leaveOtherRooms(c);
  final code = c.db.newCode(kRooms);
  c.db.set('$kRooms/$code', {
    'code': code,
    'host': c.uid,
    'players': {
      c.uid: {'name': c.name, 'online': true},
    },
    'invite': null,
    'game': null,
    'event': null,
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
  if (!players.containsKey(c.uid) && players.length >= 2) return false;

  _leaveOtherRooms(c, code);
  final fresh = c.db.get(path)!;
  (fresh['players'] as Map<String, dynamic>)[c.uid] = {
    'name': c.name,
    'online': true,
  };
  c.db.set(path, fresh);
  return true;
}

void _leave(Ctx c, Map<String, dynamic> p) =>
    _removeFrom(c, '$kRooms/${pCode(p)}');

/// Foydalanuvchi hozir qaysi xonada (ilova qayta ochilganda qaytish uchun).
String? _mine(Ctx c, Map<String, dynamic> p) {
  for (final path in c.db.pathsIn(kRooms)) {
    final d = c.db.get(path)!;
    if ((d['players'] as Map).containsKey(c.uid)) return d['code'] as String;
  }
  return null;
}

/// O'yin taklif qilish (xonadagi istalgan o'yinchi).
void _invite(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final game = pStr(p, 'game', maxLen: 20);
  final options = _validOptions(
      game, p['options'] is Map ? Map<String, dynamic>.from(p['options'] as Map) : {});
  final d = _requireMember(c, code);
  if ((d['players'] as Map).length < 2) {
    throw GameError("Ikkinchi o'yinchi hali kirmadi");
  }
  if (d['game'] != null) throw GameError("O'yin allaqachon ketyapti");
  d['invite'] = {'game': game, 'options': options, 'from': c.uid};
  c.db.set('$kRooms/$code', d);
}

/// Taklifni qabul qilish — o'yin boshlanadi.
void _accept(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requireMember(c, code);
  final invite = d['invite'] as Map<String, dynamic>?;
  if (invite == null) throw GameError('Taklif bekor qilingan');
  if (invite['from'] == c.uid) return;
  final inviter = invite['from'] as String;
  if (!(d['players'] as Map).containsKey(inviter)) {
    throw GameError('Raqib xonadan chiqib ketgan');
  }
  final start = _games[invite['game']];
  if (start == null) throw GameError("Noma'lum o'yin");

  d['game'] = start(
      Map<String, dynamic>.from(invite['options'] as Map), inviter, c.uid);
  d['invite'] = null;
  c.db.set('$kRooms/$code', d);
}

/// Taklifni rad etish yoki bekor qilish (ikkala tomon ham).
void _declineInvite(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requireMember(c, code);
  if (d['invite'] == null) return;
  d['invite'] = null;
  c.db.set('$kRooms/$code', d);
}

/// O'yinni tugatib, ikkalasini ham xonaga qaytarish.
void _endGame(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requireMember(c, code);
  if (d['game'] == null) return;
  d['game'] = null;
  _event(d, 'ended', c);
  c.db.set('$kRooms/$code', d);
}

/// Onlayn/oflayn holatini o'yinchining xonasida yangilaydi.
void updatePresence(Store db, String uid, bool online) {
  for (final path in db.pathsIn(kRooms)) {
    final d = db.get(path)!;
    final player = (d['players'] as Map)[uid];
    if (player is Map && player['online'] != online) {
      player['online'] = online;
      db.set(path, d);
    }
  }
}

Map<String, Handler> roomHandlers() => {
      'room.create': _create,
      'room.join': _join,
      'room.leave': (c, p) => _leave(c, p),
      'room.mine': _mine,
      'room.invite': (c, p) => _invite(c, p),
      'room.accept': (c, p) => _accept(c, p),
      'room.decline': (c, p) => _declineInvite(c, p),
      'room.endGame': (c, p) => _endGame(c, p),
      ...xoHandlers(),
    };
