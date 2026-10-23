import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/quiz_questions.dart';

class QuizService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _genCode() {
    const c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => c[r.nextInt(c.length)]).join();
  }

  List<Map<String, dynamic>> _pickQuestions(int count) {
    final shuffled = List.of(kQuestions)..shuffle();
    return shuffled.take(count).toList();
  }

  Future<String> createRoom(int questionCount) async {
    final code = _genCode();
    await _db.collection('quiz_rooms').doc(code).set({
      'roomCode': code,
      'host': {'uid': myUid, 'name': myName},
      'questions': _pickQuestions(questionCount),
      'players': {
        myUid: {'name': myName, 'score': 0, 'answer': -1},
      },
      'currentQuestion': -1,
      'questionStartedAt': null,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<bool> joinRoom(String code) async {
    final ref = _db.collection('quiz_rooms').doc(code.toUpperCase());
    final doc = await ref.get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if (data['status'] != 'waiting') return false;
    if ((data['players'] as Map).containsKey(myUid)) return true;

    await ref.update({
      'players.$myUid': {'name': myName, 'score': 0, 'answer': -1},
    });
    return true;
  }

  Future<void> startQuiz(String code) async {
    await _db.collection('quiz_rooms').doc(code).update({
      'currentQuestion': 0,
      'questionStartedAt': FieldValue.serverTimestamp(),
      'status': 'playing',
    });
  }

  Future<void> submitAnswer(
      String code, int answerIndex, int score) async {
    await _db.collection('quiz_rooms').doc(code).update({
      'players.$myUid.answer': answerIndex,
      'players.$myUid.score': FieldValue.increment(score),
    });
  }

  Future<void> nextQuestion(String code, int current, int total) async {
    final next = current + 1;
    if (next >= total) {
      await _db.collection('quiz_rooms').doc(code).update({
        'currentQuestion': next,
        'status': 'finished',
      });
    } else {
      final players = (await _db.collection('quiz_rooms').doc(code).get())
          .data()!['players'] as Map;
      final resetAnswers = {
        for (final uid in players.keys) 'players.$uid.answer': -1,
      };
      await _db.collection('quiz_rooms').doc(code).update({
        ...resetAnswers,
        'currentQuestion': next,
        'questionStartedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<DocumentSnapshot> gameStream(String code) =>
      _db.collection('quiz_rooms').doc(code).snapshots();

  Future<void> deleteRoom(String code) =>
      _db.collection('quiz_rooms').doc(code).delete();
}
