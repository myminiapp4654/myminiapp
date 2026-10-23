import '../net/server_client.dart';

class ScrambledWordService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  Stream<Doc> gameStream(String code) => _s.watch('games_scramble/$code');

  Future<void> placeLetter(String code, int slotIndex, String letter) =>
      _s.call('scramble.place',
          {'code': code, 'slot': slotIndex, 'letter': letter});

  Future<void> playAgain(String code) =>
      _s.call('scramble.again', {'code': code});

  Future<void> deleteRoom(String code) =>
      _s.call('scramble.delete', {'code': code});
}
