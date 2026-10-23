import 'package:oyinim_core/oyinim_core.dart';

import '../net/server_client.dart';

class CheckersService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  /// Tanlangan dona uchun yurishlar (ekranda ko'rsatish uchun).
  /// Server ham xuddi shu qoida bilan tekshiradi.
  List<Map<String, int>> validMoves(
          List<String> board, int from, int chainJump) =>
      CheckersRules.validMoves(board, from, chainJump);

  Future<void> makeMove(String roomCode, int from, Map<String, int> move) =>
      _s.call('checkers.move',
          {'code': roomCode, 'from': from, 'to': move['to']});

  Stream<Doc> gameStream(String roomCode) => _s.watch('checkers/$roomCode');

  Future<void> deleteRoom(String roomCode) =>
      _s.call('checkers.delete', {'code': roomCode});
}
