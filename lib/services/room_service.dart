import '../net/server_client.dart';

class RoomService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;

  Future<String> createRoom() async =>
      (await _s.call<String>('room.create'))!;

  /// Xona topilmasa yoki to'la bo'lsa false.
  Future<bool> joinRoom(String code) async =>
      (await _s.call<bool>('room.join', {'code': code.toUpperCase()})) ?? false;

  Future<void> leaveRoom(String code) =>
      _s.call('room.leave', {'code': code});

  /// Hozir qaysi xonadaman (ilova qayta ochilganda qaytish uchun).
  Future<String?> myRoom() => _s.call<String>('room.mine');

  Stream<Doc> roomStream(String code) => _s.watch('rooms/$code');

  // ---- o'yin taklifi ----

  Future<void> invite(String code, String game, Map<String, dynamic> options) =>
      _s.call('room.invite', {'code': code, 'game': game, 'options': options});

  Future<void> accept(String code) => _s.call('room.accept', {'code': code});

  /// Taklifni rad etish yoki bekor qilish.
  Future<void> decline(String code) => _s.call('room.decline', {'code': code});

  /// O'yinni tugatib, ikkalasini xonaga qaytarish.
  Future<void> endGame(String code) => _s.call('room.endGame', {'code': code});

  // ---- X-O ----

  Future<void> xoMove(String code, int index) =>
      _s.call('xo.move', {'code': code, 'index': index});

  Future<void> xoRematch(String code) =>
      _s.call('xo.rematch', {'code': code});
}
