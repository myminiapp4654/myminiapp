import '../net/server_client.dart';

class QuizService {
  final _s = ServerClient.instance;

  String get myUid => _s.myUid;
  String get myName => _s.myName;

  Future<void> startQuiz(String code) =>
      _s.call('quiz.start', {'code': code});

  /// Ball serverda hisoblanadi (javob tezligiga qarab).
  Future<void> submitAnswer(String code, int answerIndex) =>
      _s.call('quiz.answer', {'code': code, 'index': answerIndex});

  Future<void> nextQuestion(String code, int current) =>
      _s.call('quiz.next', {'code': code, 'current': current});

  Stream<Doc> gameStream(String code) => _s.watch('quiz_rooms/$code');

  Future<void> deleteRoom(String code) =>
      _s.call('quiz.delete', {'code': code});
}
