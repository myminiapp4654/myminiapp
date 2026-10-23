import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HaYoqService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _genCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createRoom(int questionCount) async {
    final code = _genCode();
    await _db.collection('ha_yoq_rooms').doc(code).set({
      'roomCode': code,
      'host': myUid,
      'players': {myUid: {'name': myName}},
      'playerOrder': [myUid],
      'questionCount': questionCount,
      'status': 'waiting',
      'currentAskerIndex': 0,
      'currentAnswererIndex': 1,
      'askedCount': 0,
      'completedRounds': 0,
      'pendingQuestion': null,
      'log': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<bool> joinRoom(String code) async {
    final ref = _db.collection('ha_yoq_rooms').doc(code.toUpperCase());
    final doc = await ref.get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if (data['status'] != 'waiting') return false;
    if ((data['players'] as Map).containsKey(myUid)) return true;

    final order = List<String>.from(data['playerOrder'])..add(myUid);
    await ref.update({
      'players.$myUid': {'name': myName},
      'playerOrder': order,
    });
    return true;
  }

  Future<void> startGame(String code) async {
    await _db.collection('ha_yoq_rooms').doc(code).update({'status': 'playing'});
  }

  Future<void> askQuestion(String code, String question) async {
    await _db.collection('ha_yoq_rooms').doc(code).update({'pendingQuestion': question});
  }

  Future<void> answerQuestion(String code, String answer) async {
    final ref = _db.collection('ha_yoq_rooms').doc(code);
    final data = (await ref.get()).data()!;

    final order = List<String>.from(data['playerOrder']);
    final askerIdx = data['currentAskerIndex'] as int;
    final answererIdx = data['currentAnswererIndex'] as int;
    final players = data['players'] as Map;
    final qCount = data['questionCount'] as int;
    int asked = (data['askedCount'] as int) + 1;
    int completed = data['completedRounds'] as int;

    final log = List<dynamic>.from(data['log'])
      ..add({
        'askerUid': order[askerIdx],
        'askerName': players[order[askerIdx]]['name'],
        'answererUid': order[answererIdx],
        'answererName': players[order[answererIdx]]['name'],
        'question': data['pendingQuestion'],
        'answer': answer,
      });

    final Map<String, dynamic> update = {'log': log, 'pendingQuestion': null};

    if (asked >= qCount) {
      completed++;
      if (completed >= order.length) {
        update['status'] = 'finished';
        update['askedCount'] = asked;
        update['completedRounds'] = completed;
      } else {
        final nAsker = (askerIdx + 1) % order.length;
        update['currentAskerIndex'] = nAsker;
        update['currentAnswererIndex'] = (nAsker + 1) % order.length;
        update['askedCount'] = 0;
        update['completedRounds'] = completed;
      }
    } else {
      update['askedCount'] = asked;
    }

    await ref.update(update);
  }

  Stream<DocumentSnapshot> gameStream(String code) =>
      _db.collection('ha_yoq_rooms').doc(code).snapshots();

  Future<void> deleteRoom(String code) =>
      _db.collection('ha_yoq_rooms').doc(code).delete();
}
