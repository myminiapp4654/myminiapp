import '../net/server_client.dart';

class RoomService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  Future<String> createRoom() async =>
      (await _s.call<String>('room.create'))!;

  /// Xona topilmasa yoki to'la bo'lsa false.
  Future<bool> joinRoom(String code) async =>
      (await _s.call<bool>('room.join', {'code': code.toUpperCase()})) ?? false;

  /// Xo'jayin o'yin tanlaydi: server o'yinni yaratib, taklif yuboradi.
  Future<String> proposeGame(String code, String game,
          {Map<String, dynamic>? options}) async =>
      (await _s.call<String>('room.propose',
          {'code': code, 'game': game, 'options': options ?? {}}))!;

  /// Mehmon taklifni qabul qiladi (o'yinga ham shu yerda qo'shiladi).
  Future<void> acceptInvite(String code) =>
      _s.call('room.accept', {'code': code});

  Future<void> rejectInvite(String code) =>
      _s.call('room.reject', {'code': code});

  Future<void> resetAfterGame(String code) =>
      _s.call('room.reset', {'code': code});

  Future<void> leaveRoom(String code) =>
      _s.call('room.leave', {'code': code});

  Stream<Doc> roomStream(String code) => _s.watch('rooms/$code');
}
