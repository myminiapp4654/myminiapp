import '../net/server_client.dart';

class WordPuzzleService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  Future<void> pickLetter(String roomCode, String letter) =>
      _s.call('wp.pick', {'code': roomCode, 'letter': letter});

  /// Yulduz evaziga harf ochadi. Yulduz yetmasa false.
  Future<bool> revealWithStar(String roomCode) async =>
      (await _s.call<bool>('wp.reveal', {'code': roomCode})) ?? false;

  Future<void> nextLevel(String roomCode, int newLevel) =>
      _s.call('wp.next', {'code': roomCode, 'level': newLevel});

  Stream<Doc> gameStream(String roomCode) =>
      _s.watch('word_puzzle/$roomCode');

  Future<void> deleteRoom(String roomCode) =>
      _s.call('wp.delete', {'code': roomCode});
}
