import '../net/server_client.dart';

/// X-O o'yini (5 tasi bir qatorda).
class GameService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  Future<void> makeMove(String roomCode, int index) =>
      _s.call('ttt.move', {'code': roomCode, 'index': index});

  Stream<Doc> gameStream(String roomCode) => _s.watch('games/$roomCode');

  Future<void> deleteRoom(String roomCode) =>
      _s.call('ttt.delete', {'code': roomCode});
}
