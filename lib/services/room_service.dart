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

  Stream<Doc> roomStream(String code) => _s.watch('rooms/$code');
}
