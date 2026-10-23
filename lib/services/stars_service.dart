import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StarsService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;

  Stream<int> starsStream() => _db
      .collection('user_stars')
      .doc(myUid)
      .snapshots()
      .map((s) => (s.data()?['stars'] as int?) ?? 0);

  Future<void> addStars(String uid, int count) => _db
      .collection('user_stars')
      .doc(uid)
      .set({'stars': FieldValue.increment(count)}, SetOptions(merge: true));

  Future<bool> spendStar() async {
    final ref = _db.collection('user_stars').doc(myUid);
    bool spent = false;
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final current = (doc.data()?['stars'] as int?) ?? 0;
      if (current > 0) {
        tx.set(ref, {'stars': current - 1}, SetOptions(merge: true));
        spent = true;
      }
    });
    return spent;
  }
}
