import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _genCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createRoom() async {
    final code = _genCode();
    await _db.collection('rooms').doc(code).set({
      'code': code,
      'host': myUid,
      'players': {myUid: {'name': myName}},
      'status': 'waiting',
      'gameInvite': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<bool> joinRoom(String code) async {
    final ref = _db.collection('rooms').doc(code.toUpperCase());
    final doc = await ref.get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final players = data['players'] as Map;
    if (players.containsKey(myUid)) return true;
    if (players.length >= 2) return false;

    await ref.update({'players.$myUid': {'name': myName}});
    return true;
  }

  Future<void> proposeGame(String code, String game, String gameCode) async {
    await _db.collection('rooms').doc(code).update({
      'status': 'invited',
      'gameInvite': {
        'game': game,
        'gameCode': gameCode,
        'invitedBy': myUid,
        'response': null,
      },
    });
  }

  Future<void> acceptInvite(String code) async {
    await _db.collection('rooms').doc(code).update({
      'gameInvite.response': 'accepted',
      'status': 'playing',
    });
  }

  Future<void> rejectInvite(String code) async {
    await _db.collection('rooms').doc(code).update({
      'gameInvite': null,
      'status': 'waiting',
    });
  }

  Future<void> resetAfterGame(String code) async {
    final doc = await _db.collection('rooms').doc(code).get();
    if (!doc.exists) return;
    await _db.collection('rooms').doc(code).update({
      'gameInvite': null,
      'status': 'waiting',
    });
  }

  Future<void> leaveRoom(String code) async {
    final ref = _db.collection('rooms').doc(code);
    final doc = await ref.get();
    if (!doc.exists) return;
    final players = (doc.data()!['players'] as Map);
    if (players.length <= 1) {
      await ref.delete();
    } else {
      await ref.update({'players.$myUid': FieldValue.delete()});
    }
  }

  Stream<DocumentSnapshot> roomStream(String code) =>
      _db.collection('rooms').doc(code).snapshots();
}
