import '../net/server_client.dart';

class HaYoqService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  Future<void> startGame(String code) =>
      _s.call('hayoq.start', {'code': code});

  Future<void> askQuestion(String code, String question) =>
      _s.call('hayoq.ask', {'code': code, 'question': question});

  Future<void> answerQuestion(String code, String answer) =>
      _s.call('hayoq.answer', {'code': code, 'answer': answer});

  Stream<Doc> gameStream(String code) => _s.watch('ha_yoq_rooms/$code');

  Future<void> deleteRoom(String code) =>
      _s.call('hayoq.delete', {'code': code});
}
